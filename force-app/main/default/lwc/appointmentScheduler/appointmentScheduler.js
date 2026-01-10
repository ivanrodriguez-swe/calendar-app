import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAppointmentRequestInfo from '@salesforce/apex/VolunteerAvailabilityController.getAppointmentRequestInfo';
import getAllAvailableSlots from '@salesforce/apex/VolunteerAvailabilityController.getAllAvailableSlots';
import bookSlotWithRandomVolunteer from '@salesforce/apex/VolunteerAvailabilityController.bookSlotWithRandomVolunteer';

export default class AppointmentScheduler extends LightningElement {
    @track loading = true;
    @track showBookingModal = false;
    @track selectedSlot = null;
    @track bookingInProgress = false;
    @track groupedSlots = [];
    @track referenceName = '';
    @track appointmentBooked = false;
    @track referencePhone = '';
    
    @api appointmentRequestId = null;
    
    get hasAvailableSlots() {
        return this.groupedSlots && this.groupedSlots.length > 0;
    }
    
    get hasReferenceName() {
        return this.referenceName && this.referenceName.trim().length > 0;
    }

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        const urlRequestId = urlParams.get('requestId');
        const effectiveRequestId = urlRequestId || this.appointmentRequestId;
        
        if (effectiveRequestId) {
            this.appointmentRequestId = effectiveRequestId;
            this.fetchAppointmentRequestInfo();
        } else {
            this.loading = false;
            this.groupedSlots = [];
        }
    }
    
    fetchAppointmentRequestInfo() {
        getAppointmentRequestInfo({ requestId: this.appointmentRequestId })
            .then(result => {
                if (result) {
                    this.referenceName = result.referenceName || '';
                    
                    if (result.status === 'Reserved' || result.status === 'Completed') {
                        this.appointmentBooked = true;
                        this.loading = false;
                        this.groupedSlots = [];
                        return;
                    }
                    
                    this.fetchAvailableSlots();
                } else {
                    this.referenceName = '';
                    this.loading = false;
                    this.groupedSlots = [];
                }
            })
            .catch(() => {
                this.referenceName = '';
                this.loading = false;
                this.groupedSlots = [];
            });
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
        grouped.sort((a, b) => a.date < b.date ? -1 : 1);
        
        grouped.forEach(dateGroup => {
            dateGroup.slots.sort((a, b) => a.startTime < b.startTime ? -1 : 1);
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
    }

    handlePhoneChange(event) {
        this.referencePhone = event.target.value;
    }
    
    get isPhoneValid() {
        return this.referencePhone && this.referencePhone.trim().length >= 10;
    }

    parseTimeToMillis(timeStr) {
        if (!timeStr) return null;
        if (typeof timeStr === 'number') return timeStr;
        
        if (!timeStr.includes(':')) {
            return parseInt(timeStr, 10);
        }
        
        const parts = timeStr.split(':');
        const hours = parseInt(parts[0], 10);
        const minutes = parseInt(parts[1], 10);
        const seconds = parts[2] ? parseInt(parts[2], 10) : 0;
        
        return ((hours * 60 + minutes) * 60 + seconds) * 1000;
    }

    handleConfirmBooking() {
        if (!this.selectedSlot) {
            this.showToast('Error', 'Unable to process booking. Please try again.', 'error');
            return;
        }
        
        if (!this.isPhoneValid) {
            this.showToast('Error', 'Please enter a valid phone number.', 'error');
            return;
        }

        this.bookingInProgress = true;
        
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
                    this.showToast('Success', 'Appointment successfully booked!', 'success');
                    this.handleCloseModal();
                    this.appointmentBooked = true;
                    this.groupedSlots = [];
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
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
