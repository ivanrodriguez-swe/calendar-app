import { LightningElement, api } from 'lwc';
import getAppointmentRequestInfo from '@salesforce/apex/VolunteerAvailabilityController.getAppointmentRequestInfo';
import getAllAvailableSlots from '@salesforce/apex/VolunteerAvailabilityController.getAllAvailableSlots';
import bookSlotWithRandomVolunteer from '@salesforce/apex/VolunteerAvailabilityController.bookSlotWithRandomVolunteer';

export default class AppointmentScheduler extends LightningElement {
    @api appointmentRequestId = null;
    
    loading = true;
    showBookingModal = false;
    selectedSlot = null;
    bookingInProgress = false;
    groupedSlots = [];
    appointmentBooked = false;
    referencePhone = '';
    bookingError = '';
    
    get hasAvailableSlots() {
        return this.groupedSlots && this.groupedSlots.length > 0;
    }
    
   connectedCallback(){
     this.fetchAvailableSlots();
   }  

    fetchAvailableSlots() {
        this.loading = true;
        
        getAllAvailableSlots()
            .then(result => {
                this.processTimeslots(result);
            })
            .catch(() => {
                this.groupedSlots = [];
            })
            .finally(() => {
                this.loading = false;
            });
    }

    processTimeslots(result) {
        const dateMap = new Map();
        const seenSlots = new Set();
        
        if (Array.isArray(result)) {
            result.forEach(slot => {
                const dateKey = slot.day;
                const slotKey = `${slot.day}-${slot.startTime}-${slot.endTime}`;
                
                if (seenSlots.has(slotKey)) {
                    return;
                }
                seenSlots.add(slotKey);
                
                const slotData = {
                    key: slotKey,
                    date: slot.day,
                    dateFormatted: this.formatDate(slot.day),
                    timeFormatted: this.formatTimeRange(slot.startTime, slot.endTime),
                    startTime: String(slot.startTime),
                    endTime: String(slot.endTime)
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
        
        const grouped = Array.from(dateMap.values());
        grouped.sort((a, b) => (a.date < b.date ? -1 : 1));
        grouped.forEach(dateGroup => {
            dateGroup.slots.sort((a, b) => (a.startTime < b.startTime ? -1 : 1));
        });
        
        this.groupedSlots = grouped;
    }

    formatDate(dateValue) {
        if (!dateValue) return '';
        
        let date;
        if (typeof dateValue === 'string') {
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
            
            let hours, minutes;
            
            if (typeof time === 'number') {
                const totalMinutes = Math.floor(time / 60000);
                hours = Math.floor(totalMinutes / 60);
                minutes = totalMinutes % 60;
            } else if (typeof time === 'string') {
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

    handleSlotClick(event) {
        const button = event.currentTarget;
        this.selectedSlot = {
            dayLabel: button.dataset.date,
            time: button.dataset.time,
            slotDate: button.dataset.slotDate,
            startTime: button.dataset.startTime,
            endTime: button.dataset.endTime
        };
        this.showBookingModal = true;
    }

    handleCloseModal() {
        this.showBookingModal = false;
        this.selectedSlot = null;
        this.referencePhone = '';
        this.bookingError = '';
    }

    handlePhoneChange(event) {
        this.referencePhone = event.target.value;
    }
    
    validateInputs() {
        const phoneInput = this.template.querySelector('lightning-input[data-id="phoneInput"]');
        return phoneInput ? phoneInput.reportValidity() : false;
    }

    parseTimeToMillis(timeStr) {
        if (!timeStr) return null;
        if (typeof timeStr === 'number') return timeStr;
        if (!timeStr.includes(':')) return parseInt(timeStr, 10);
        
        const parts = timeStr.split(':');
        const hours = parseInt(parts[0], 10);
        const minutes = parseInt(parts[1], 10);
        const seconds = parts[2] ? parseInt(parts[2], 10) : 0;
        
        return ((hours * 60 + minutes) * 60 + seconds) * 1000;
    }

    handleConfirmBooking() {
        if (!this.selectedSlot || !this.validateInputs()) {
            return;
        }

        this.bookingInProgress = true;
        this.bookingError = '';
        
        const request = {
            slotDate: this.selectedSlot.slotDate,
            startTime: this.parseTimeToMillis(this.selectedSlot.startTime),
            endTime: this.parseTimeToMillis(this.selectedSlot.endTime),
            appointmentRequestId: this.appointmentRequestId,
            referencePhone: this.referencePhone.trim()
        };
        
        bookSlotWithRandomVolunteer({ request })
            .then(result => {
                if (result.success) {
                    this.handleCloseModal();
                    this.appointmentBooked = true;
                    this.groupedSlots = [];
                } else {
                    this.bookingError = result.message || 'Unable to book this time slot.';
                }
            })
            .catch(error => {
                this.bookingError = error.body?.message || 'An error occurred while booking the time slot.';
            })
            .finally(() => {
                this.bookingInProgress = false;
            });
    }
}
