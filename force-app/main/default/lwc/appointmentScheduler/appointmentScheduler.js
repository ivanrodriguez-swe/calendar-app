import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import APPOINTMENT_REQUEST_VOLUNTEER from '@salesforce/schema/Appointment_Request__c.Volunteer__c';
import getAvailableSlotsByVolunteer from '@salesforce/apex/VolunteerAvailabilityController.getAvailableSlotsByVolunteer';
import bookTimeSlot from '@salesforce/apex/VolunteerAvailabilityController.bookTimeSlot';

export default class AppointmentScheduler extends LightningElement {
    @track loading = true;
    @track showBookingModal = false;
    @track selectedSlot = null;
    @track bookingInProgress = false;
    @track groupedSlots = [];
    
    @api appointmentRequestId = null;
    volunteerId = null;
    _appointmentRequestIdForWire = null;
    
    get hasAvailableSlots() {
        return this.groupedSlots && this.groupedSlots.length > 0;
    }

    @wire(getRecord, { 
        recordId: '$_appointmentRequestIdForWire', 
        fields: [APPOINTMENT_REQUEST_VOLUNTEER]
    })
    wiredAppointmentRequest({ error, data }) {
        if (data) {
            this.volunteerId = getFieldValue(data, APPOINTMENT_REQUEST_VOLUNTEER);
            this.fetchAvailableSlots();
        } else if (error) {
            console.error('Error fetching Appointment Request:', error);
            this.volunteerId = null;
            this.loading = false;
        }
    }

    connectedCallback() {
        // Get appointmentRequestId from URL if not set via property
        if (!this.appointmentRequestId) {
            const urlParams = new URLSearchParams(window.location.search);
            this.appointmentRequestId = urlParams.get('requestId');
        }
        
        // Set the wire variable to trigger the wire adapter
        if (this.appointmentRequestId) {
            this._appointmentRequestIdForWire = this.appointmentRequestId;
        } else {
            // No appointment request, fetch all available slots
            this.fetchAvailableSlots();
        }
    }

    fetchAvailableSlots() {
        this.loading = true;
        
        getAvailableSlotsByVolunteer({ volunteerId: this.volunteerId })
            .then(result => {
                this.processTimeslots(result);
            })
            .catch(error => {
                console.error('Error fetching timeslots:', error);
                this.groupedSlots = [];
            })
            .finally(() => {
                this.loading = false;
            });
    }

    processTimeslots(result) {
        const dateMap = new Map();
        
        if (Array.isArray(result)) {
            result.forEach(slot => {
                const dateKey = slot.day;
                const slotData = {
                    id: slot.id,
                    date: slot.day,
                    dateFormatted: this.formatDate(slot.day),
                    timeFormatted: this.formatTimeRange(slot.startTime, slot.endTime),
                    startTime: slot.startTime,
                    endTime: slot.endTime,
                    volunteerId: slot.volunteerId,
                    volunteerName: slot.volunteerName
                };
                
                if (!dateMap.has(dateKey)) {
                    dateMap.set(dateKey, {
                        date: dateKey,
                        dateFormatted: this.formatDate(slot.day),
                        slots: []
                    });
                }
                dateMap.get(dateKey).slots.push(slotData);
            });
        }
        
        // Convert map to array and sort by date
        const grouped = Array.from(dateMap.values());
        grouped.sort((a, b) => a.date < b.date ? -1 : 1);
        
        // Sort slots within each date by time
        grouped.forEach(dateGroup => {
            dateGroup.slots.sort((a, b) => a.startTime < b.startTime ? -1 : 1);
        });
        
        this.groupedSlots = grouped;
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        
        // Handle both string and Date formats
        let date;
        if (typeof dateValue === 'string') {
            // Parse YYYY-MM-DD format
            const parts = dateValue.split('-');
            date = new Date(parts[0], parts[1] - 1, parts[2]);
        } else {
            date = new Date(dateValue);
        }
        
        return date.toLocaleDateString(undefined, { 
            weekday: 'short', 
            year: 'numeric', 
            month: 'short', 
            day: 'numeric' 
        });
    }

    formatTimeRange(startTime, endTime) {
        const formatTime = (time) => {
            if (!time) return '';
            
            // Handle Time object from Apex (comes as milliseconds or time string)
            let hours, minutes;
            
            if (typeof time === 'number') {
                // Milliseconds since midnight
                const totalMinutes = Math.floor(time / 60000);
                hours = Math.floor(totalMinutes / 60);
                minutes = totalMinutes % 60;
            } else if (typeof time === 'string') {
                // Format: "HH:MM:SS.000Z"
                const parts = time.split(':');
                hours = parseInt(parts[0], 10);
                minutes = parseInt(parts[1], 10);
            } else {
                return '';
            }
            
            const ampm = hours >= 12 ? 'PM' : 'AM';
            hours = hours % 12 || 12;
            return `${hours}:${String(minutes).padStart(2, '0')} ${ampm}`;
        };
        
        return `${formatTime(startTime)} - ${formatTime(endTime)}`;
    }

    toISODate(dateObj) {
        const yyyy = dateObj.getFullYear();
        const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
        const dd = String(dateObj.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    handleSlotClick(event) {
        const slotId = event.target.dataset.slotId;
        const dateFormatted = event.target.dataset.date;
        const timeFormatted = event.target.dataset.time;
        const volunteerName = event.target.dataset.volunteer;
        
        this.selectedSlot = {
            id: slotId,
            dayLabel: dateFormatted,
            time: timeFormatted,
            volunteerName: volunteerName || 'Assigned Volunteer'
        };
        this.showBookingModal = true;
    }

    handleCloseModal() {
        this.showBookingModal = false;
        this.selectedSlot = null;
    }

    handleConfirmBooking() {
        if (!this.selectedSlot) {
            this.showToast('Error', 'Unable to process booking. Please try again.', 'error');
            return;
        }

        this.bookingInProgress = true;
        bookTimeSlot({ 
            timeSlotId: this.selectedSlot.id, 
            customerId: null,
            appointmentRequestId: this.appointmentRequestId
        })
        .then(result => {
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.handleCloseModal();
                this.fetchAvailableSlots(); // Refresh the list
            } else {
                this.showToast('Error', result.message, 'error');
            }
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'An error occurred while booking the time slot', 'error');
        })
        .finally(() => {
            this.bookingInProgress = false;
        });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
}
