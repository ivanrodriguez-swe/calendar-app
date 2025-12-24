import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getVolunteerAvailabilityData from '@salesforce/apex/VolunteerAvailabilityController.getVolunteerAvailabilityData';

export default class VolunteerAvailabilityDisplay extends LightningElement {
    @track rows = [];
    @track fromDate;
    @track toDate;
    @track isLoading = false;
    @track hasMore = false;
    @track totalCount = 0;
    
    currentOffset = 0;
    refreshIntervalId;
    PAGE_SIZE = 50;
    REFRESH_INTERVAL = 30000; // 30 seconds
    
    connectedCallback() {
        // Initialize with no date filters - will load ALL records
        this.fromDate = null;
        this.toDate = null;
        
        // Load initial data (all records)
        this.loadData();
        
        // Set up auto-refresh polling
        this.refreshIntervalId = setInterval(() => {
            this.refreshData();
        }, this.REFRESH_INTERVAL);
    }
    
    disconnectedCallback() {
        if (this.refreshIntervalId) {
            clearInterval(this.refreshIntervalId);
        }
    }
    
    formatDateForInput(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }
    
    handleFromDateChange(event) {
        this.fromDate = event.target.value;
    }
    
    handleToDateChange(event) {
        this.toDate = event.target.value;
    }
    
    handleSearch() {
        // Validate dates if provided
        if (this.fromDate && this.toDate && this.toDate < this.fromDate) {
            this.showToast('Error', 'To date must be greater than or equal to From date', 'error');
            return;
        }
        
        // When both From and To dates are set, filter records within that date range
        // Reset pagination and load data (with or without filters)
        this.currentOffset = 0;
        this.rows = [];
        this.hasMore = false;
        this.loadData();
    }
    
    loadData() {
        if (this.isLoading) {
            return;
        }
        
        this.isLoading = true;
        
        // Apex expects dates as strings in YYYY-MM-DD format, or null for all records
        // If dates are not set, pass null to get ALL records from database
        // If both dates are set, Apex will filter records where Day__c is between startDate and endDate (inclusive)
        const startDate = this.fromDate || null;
        const endDate = this.toDate || null;
        
        console.log('Loading data with dates:', { startDate, endDate, offset: this.currentOffset, pageSize: this.PAGE_SIZE });
        if (startDate && endDate) {
            if (startDate === endDate) {
                console.log('Filtering records for single date:', startDate);
            } else {
                console.log('Filtering records for date range:', startDate, 'to', endDate);
            }
        }
        
        getVolunteerAvailabilityData({
            startDate: startDate,
            endDate: endDate,
            offset: this.currentOffset,
            pageSize: this.PAGE_SIZE
        })
        .then(result => {
            console.log('Data loaded:', result);
            console.log('Result rows:', result?.rows);
            console.log('Result rows length:', result?.rows?.length);
            
            // Append new rows to existing rows
            if (result && result.rows && result.rows.length > 0) {
                console.log('Adding rows:', result.rows.length);
                this.rows = [...this.rows, ...result.rows];
            } else {
                console.log('No rows returned from server. Result:', result);
            }
            
            this.totalCount = (result && result.totalCount) ? result.totalCount : 0;
            this.hasMore = (result && result.hasMore) ? result.hasMore : false;
            this.currentOffset = this.rows.length;
            
            console.log('Updated state:', { rowsCount: this.rows.length, totalCount: this.totalCount, hasMore: this.hasMore });
            
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error loading data:', error);
            console.error('Error body:', error.body);
            console.error('Error message:', error.message);
            console.error('Error stack:', error.stack);
            this.showToast('Error', this.getErrorMessage(error), 'error');
            this.isLoading = false;
        });
    }
    
    handleLoadMore() {
        if (this.hasMore && !this.isLoading) {
            this.loadData();
        }
    }
    
    refreshData() {
        // Only refresh if we have data loaded
        if (this.rows.length === 0 || this.isLoading) {
            return;
        }
        
        const startDate = this.fromDate || null;
        const endDate = this.toDate || null;
        
        // Get all current rows to compare (with or without date filters)
        getVolunteerAvailabilityData({
            startDate: startDate,
            endDate: endDate,
            offset: 0,
            pageSize: this.rows.length
        })
        .then(result => {
            if (result.rows && result.rows.length > 0) {
                // Create a map of existing rows by time slot ID for quick lookup
                const existingRowMap = new Map();
                this.rows.forEach(row => {
                    if (row.timeSlots) {
                        row.timeSlots.forEach(slot => {
                            if (slot.id) {
                                existingRowMap.set(slot.id, slot);
                            }
                        });
                    }
                });
                
                // Update status of existing time slots
                result.rows.forEach(newRow => {
                    if (newRow.timeSlots) {
                        newRow.timeSlots.forEach(newSlot => {
                            if (newSlot.id && existingRowMap.has(newSlot.id)) {
                                const existingSlot = existingRowMap.get(newSlot.id);
                                if (existingSlot.status !== newSlot.status) {
                                    existingSlot.status = newSlot.status;
                                }
                            }
                        });
                    }
                });
                
                // Trigger reactivity
                this.rows = [...this.rows];
            }
        })
        .catch(error => {
            console.error('Error refreshing data:', error);
            // Silently fail for refresh - don't show toast
        });
    }
    
    get hasData() {
        return this.rows && this.rows.length > 0;
    }
    
    get displayRows() {
        if (!this.rows || this.rows.length === 0) {
            return [];
        }
        
        return this.rows.map((row, index) => {
            // Process time slots to add bubble class
            const processedTimeSlots = row.timeSlots ? row.timeSlots.map(slot => {
                return {
                    ...slot,
                    bubbleClass: slot.status === 'Available' ? 'bubble-available' : 'bubble-booked'
                };
            }) : [];
            
            // Create a unique key for the row
            const rowKey = row.volunteerId + '-' + (row.slotDate ? row.slotDate.toString() : index);
            
            return {
                ...row,
                rowKey: rowKey,
                showVolunteerName: this.shouldShowVolunteerName(index),
                formattedDate: this.formatDate(row.slotDate),
                timeSlots: processedTimeSlots
            };
        });
    }
    
    shouldShowVolunteerName(index) {
        if (index === 0) {
            return true;
        }
        
        const currentRow = this.rows[index];
        const previousRow = this.rows[index - 1];
        
        return currentRow.volunteerId !== previousRow.volunteerId;
    }
    
    formatDate(dateValue) {
        if (!dateValue) {
            return '';
        }
        
        const date = new Date(dateValue);
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
    
    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (error.message) {
            return error.message;
        }
        return 'An unknown error occurred';
    }
}

