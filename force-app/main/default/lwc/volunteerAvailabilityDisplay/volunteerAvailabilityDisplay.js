import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getVolunteerAvailabilityData from '@salesforce/apex/VolunteerAvailabilityDisplayController.getVolunteerAvailabilityData';

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
        
        getVolunteerAvailabilityData({
            startDate: startDate,
            endDate: endDate,
            offset: this.currentOffset,
            pageSize: this.PAGE_SIZE
        })
        .then(result => {
            // Append new rows to existing rows
            if (result && result.rows && result.rows.length > 0) {
                this.rows = [...this.rows, ...result.rows];
            }
            
            this.totalCount = (result && result.totalCount) ? result.totalCount : 0;
            this.hasMore = (result && result.hasMore) ? result.hasMore : false;
            this.currentOffset = this.rows.length;
            
            this.isLoading = false;
        })
        .catch(error => {
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
            // Silently fail for refresh - don't show toast to avoid interrupting user experience
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
        
        // CRITICAL FIX: Parse the date string directly to avoid timezone conversion
        // Apex sends dates as ISO strings (e.g., "2025-12-22T00:00:00.000Z")
        // When we use new Date(), it interprets in UTC and toLocaleDateString() converts to local timezone,
        // which can shift the date by one day. Instead, extract the date components directly from the string.
        
        let dateStr;
        if (typeof dateValue === 'string') {
            // If it's already a string, use it directly
            dateStr = dateValue;
        } else {
            // If it's a Date object, convert to ISO string
            dateStr = dateValue.toISOString();
        }
        
        // Extract date components from ISO string (YYYY-MM-DDTHH:mm:ss.sssZ)
        // Take only the date part (YYYY-MM-DD) before the 'T'
        const datePart = dateStr.split('T')[0];
        const [year, month, day] = datePart.split('-').map(Number);
        
        // Create a date object using local timezone components (not UTC)
        // This ensures the date displays as the actual date value, not shifted by timezone
        const date = new Date(year, month - 1, day);
        const options = { year: 'numeric', month: 'short', day: 'numeric' };
        return date.toLocaleDateString('en-US', options);
    }
    
    /**
     * Format time slot for display (fallback method if timeLabel is not provided)
     * This method ensures times are displayed correctly regardless of timezone.
     * 
     * NOTE: Times are typically pre-formatted in Apex (timezone-safe).
     * This is a fallback for edge cases.
     * 
     * @param {Time|String|Date} startTime - Start time
     * @param {Time|String|Date} endTime - End time
     * @returns {String} Formatted time range (e.g., "9:00 AM - 9:15 AM")
     */
    formatTimeSlot(startTime, endTime) {
        if (!startTime || !endTime) {
            return '';
        }
        
        // Time values from Apex are time-of-day only (no timezone)
        // They may come as strings (e.g., "09:00:00.000Z") or Time objects
        // Extract hours and minutes directly without timezone conversion
        
        const formatSingleTime = (timeValue) => {
            let hours, minutes;
            
            if (typeof timeValue === 'string') {
                // Parse from string format (e.g., "09:00:00.000Z" or "09:00:00")
                const timePart = timeValue.split('T')[1] || timeValue; // Handle both DateTime and Time strings
                const timeOnly = timePart.split('.')[0]; // Remove milliseconds
                const [h, m] = timeOnly.split(':').map(Number);
                hours = h;
                minutes = m || 0;
            } else if (timeValue instanceof Date) {
                // If it's a Date object, extract hours and minutes
                // Use UTC methods to avoid timezone conversion
                hours = timeValue.getUTCHours();
                minutes = timeValue.getUTCMinutes();
            } else {
                // If it's a Time object or other format, try to extract
                const timeStr = String(timeValue);
                const timePart = timeStr.split('T')[1] || timeStr;
                const timeOnly = timePart.split('.')[0];
                const [h, m] = timeOnly.split(':').map(Number);
                hours = h;
                minutes = m || 0;
            }
            
            // Format as 12-hour time with AM/PM
            const ampm = hours >= 12 ? 'PM' : 'AM';
            let displayHours = hours > 12 ? hours - 12 : hours;
            if (displayHours === 0) displayHours = 12;
            const displayMinutes = minutes < 10 ? '0' + minutes : String(minutes);
            
            return `${displayHours}:${displayMinutes} ${ampm}`;
        };
        
        return `${formatSingleTime(startTime)} - ${formatSingleTime(endTime)}`;
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

