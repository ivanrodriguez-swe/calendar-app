import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getAllVolunteers from '@salesforce/apex/VolunteerDisplayController.getAllVolunteers';
import getVolunteersWithStatistics from '@salesforce/apex/VolunteerDisplayController.getVolunteersWithStatistics';

export default class VolunteerDisplay extends LightningElement {
    @track volunteers = [];
    @track isLoading = false;
    @track showStatistics = false;
    @track fromDate;
    @track toDate;
    
    wiredVolunteersResult;
    
    // Wire to get all volunteers on component load
    @wire(getAllVolunteers)
    wiredVolunteers(result) {
        this.wiredVolunteersResult = result;
        const { error, data } = result;
        if (data) {
            this.volunteers = data.volunteers || [];
            this.isLoading = false;
        } else if (error) {
            console.error('Error loading volunteers:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
            this.isLoading = false;
        }
    }
    
    connectedCallback() {
        this.isLoading = true;
    }
    
    handleShowStatisticsChange(event) {
        this.showStatistics = event.target.checked;
        if (this.showStatistics) {
            this.loadVolunteersWithStatistics();
        } else {
            // Reload without statistics
            this.refreshVolunteers();
        }
    }
    
    handleFromDateChange(event) {
        this.fromDate = event.target.value;
        if (this.showStatistics && this.fromDate && this.toDate) {
            this.loadVolunteersWithStatistics();
        }
    }
    
    handleToDateChange(event) {
        this.toDate = event.target.value;
        if (this.showStatistics && this.fromDate && this.toDate) {
            this.loadVolunteersWithStatistics();
        }
    }
    
    loadVolunteersWithStatistics() {
        if (!this.fromDate || !this.toDate) {
            this.showToast('Info', 'Please select both From and To dates to view statistics', 'info');
            return;
        }
        
        if (this.toDate < this.fromDate) {
            this.showToast('Error', 'To date must be greater than or equal to From date', 'error');
            return;
        }
        
        this.isLoading = true;
        
        getVolunteersWithStatistics({
            startDate: this.fromDate,
            endDate: this.toDate
        })
        .then(result => {
            this.volunteers = result.volunteers || [];
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error loading volunteers with statistics:', error);
            this.showToast('Error', this.getErrorMessage(error), 'error');
            this.isLoading = false;
        });
    }
    
    refreshVolunteers() {
        this.isLoading = true;
        // Refresh the wired property
        return refreshApex(this.wiredVolunteersResult);
    }
    
    get hasVolunteers() {
        return this.volunteers && this.volunteers.length > 0;
    }
    
    get totalCount() {
        return this.volunteers ? this.volunteers.length : 0;
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

