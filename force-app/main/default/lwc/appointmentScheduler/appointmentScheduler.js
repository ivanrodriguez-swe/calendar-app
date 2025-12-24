import { LightningElement, track, wire, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import USER_EMAIL from '@salesforce/schema/User.Email';
import USER_NAME from '@salesforce/schema/User.Name';
import getTimeslotsForRange from '@salesforce/apex/VolunteerAvailabilityController.getTimeslotsForRange';
import bookTimeSlot from '@salesforce/apex/VolunteerAvailabilityController.bookTimeSlot';

export default class AppointmentScheduler extends LightningElement {
    @track loading = true;
    @track showBookingModal = false;
    @track selectedSlot = null;
    @track bookingInProgress = false;

    selectedDate;

    @track weekDays = [];

    timeslotsMap = {};

    @track timeRows = [];

    currentUserId = null;
    currentUserEmail = '';
    currentUserName = 'Guest';
    
    @api appointmentRequestId = null;
    
    get hasUserId() {
        return this.currentUserId != null;
    }

    @wire(getRecord, { 
        recordId: '$currentUserId', 
        fields: [USER_EMAIL, USER_NAME],
        optionalFields: [USER_EMAIL, USER_NAME]
    })
    wiredUser({ error, data }) {
        if (this.currentUserId && data) {
            this.currentUserEmail = data.fields.Email.value;
            this.currentUserName = data.fields.Name.value;
        } else if (error && this.currentUserId) {
        }
    }

    connectedCallback() {
        try {
            this.currentUserId = USER_ID;
        } catch (e) {
            this.currentUserId = null;
        }
        
        if (!this.appointmentRequestId) {
            const urlParams = new URLSearchParams(window.location.search);
            this.appointmentRequestId = urlParams.get('requestId');
        }
        
        if (this.appointmentRequestId) {
        }
        
        const today = new Date();
        const defaultDate = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 7);
        this.selectedDate = defaultDate;
        this.selectedDateISO = this.toISODate(this.selectedDate);
        this.buildWeekFromSelectedDate();
        this.fetchTimeslotsForWeek();
    }

    toISODate(dateObj) {
        const yyyy = dateObj.getFullYear();
        const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
        const dd = String(dateObj.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    handleDateChange(event) {
        const iso = event.target.value;
        if (iso) {
            this.selectedDateISO = iso;
            const parts = iso.split('-').map(Number);
            this.selectedDate = new Date(parts[0], parts[1] - 1, parts[2]);
            this.buildWeekFromSelectedDate();
            this.fetchTimeslotsForWeek();
        }
    }

    handleTodayWeek() {
        const today = new Date();
        this.selectedDate = today;
        this.selectedDateISO = this.toISODate(today);
        this.buildWeekFromSelectedDate();
        this.fetchTimeslotsForWeek();
    }

    buildWeekFromSelectedDate() {
        this.weekDays = [];
        const sel = new Date(this.selectedDate.getFullYear(), this.selectedDate.getMonth(), this.selectedDate.getDate());
        const dayOfWeek = sel.getDay();
        const diffToMonday = (dayOfWeek === 0) ? -6 : (1 - dayOfWeek);
        const mondayDate = new Date(sel.getFullYear(), sel.getMonth(), sel.getDate() + diffToMonday);
        for (let i = 0; i < 5; i++) {
            const d = new Date(mondayDate.getFullYear(), mondayDate.getMonth(), mondayDate.getDate() + i);
            this.weekDays.push({
                date: d,
                iso: this.toISODate(d),
                label: d.toLocaleDateString(undefined, { weekday: 'short', month: 'numeric', day: 'numeric' })
            });
        }
    }

    fetchTimeslotsForWeek() {
        this.loading = true;
        const startIso = this.weekDays[0].iso;
        const endIso = this.weekDays[this.weekDays.length - 1].iso;
        getTimeslotsForRange({ startDate: startIso, endDate: endIso })
            .then(result => {
                if (Array.isArray(result)) {
                    result.forEach(timeRow => {
                        if (timeRow.slots && Array.isArray(timeRow.slots)) {
                            timeRow.slots.forEach(slot => {
                                if (slot.day) {
                                    if (typeof slot.day === 'string') {
                                        slot.dayISO = slot.day;
                                    } else {
                                        slot.dayISO = this.toISODate(new Date(slot.day));
                                    }
                                }
                            });
                        }
                    });
                }
                this.timeslotsMap = result;
            })
            .catch(error => {
                this.timeslotsMap = {};
                this.timeRows = this.buildDefaultTimeRows();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    buildDefaultTimeRows() {
        const rows = [];
        for (let h = 9; h < 17; h++) {
            for (let m = 0; m < 60; m += 20) {
                const hh = String(h).padStart(2, '0');
                const mm = String(m).padStart(2, '0');
                const timeLabel = `${hh}:${mm}`;
                rows.push(timeLabel);
            }
        }
        return rows;
    }

    hasSlot(dayIso, timeRow) {
        return this.timeslotsMap && this.timeslotsMap[dayIso] && this.timeslotsMap[dayIso][timeRow];
    }

    getSlotId(dayIso, timeRow) {
        return (this.hasSlot(dayIso, timeRow) ? this.timeslotsMap[dayIso][timeRow].id : null);
    }

    getSlotAvailable(dayIso, timeRow) {
        return (this.hasSlot(dayIso, timeRow) ? this.timeslotsMap[dayIso][timeRow].isAvailable : false);
    }

    formatCellTime(dayIso, timeRow) {
        const slot = (this.hasSlot(dayIso, timeRow) ? this.timeslotsMap[dayIso][timeRow] : null);
        if (slot && slot.endTime) {
            const start = new Date(slot.startTime);
            const end = new Date(slot.endTime);
            const sh = String(start.getHours()).padStart(2, '0');
            const sm = String(start.getMinutes()).padStart(2, '0');
            const eh = String(end.getHours()).padStart(2, '0');
            const em = String(end.getMinutes()).padStart(2, '0');
            return `${sh}:${sm} - ${eh}:${em}`;
        }
        return timeRow;
    }

    handleSelect(event) {
        const slotId = event.currentTarget.dataset.slotId;
        const day = event.currentTarget.dataset.day;
        const timeRow = event.currentTarget.dataset.timeRow;
        const available = event.currentTarget.dataset.available === 'true';
        
        if (!slotId || !day || !timeRow) return;
        
        if (!available) {
            this.showToast('Error', 'This time slot is not available', 'error');
            return;
        }

        const dayIso = typeof day === 'string' ? day : this.toISODate(new Date(day));

        let slot = null;
        if (Array.isArray(this.timeslotsMap)) {
            for (const timeRowObj of this.timeslotsMap) {
                if (timeRowObj.label === timeRow && timeRowObj.slots) {
                    slot = timeRowObj.slots.find(s => {
                        if (s.id !== slotId) return false;
                        const slotDay = s.day ? (typeof s.day === 'string' ? s.day : this.toISODate(new Date(s.day))) : null;
                        return slotDay === dayIso;
                    });
                    if (slot) break;
                }
            }
        }

        if (!slot || !slot.id || !slot.isAvailable) {
            this.showToast('Error', 'This time slot is not available', 'error');
            return;
        }

        this.selectedSlot = {
            id: slot.id,
            day: dayIso,
            dayLabel: this.getDayLabel(dayIso),
            time: this.formatSlotTime(slot),
            volunteerName: slot.volunteerName || 'Not assigned'
        };
        this.showBookingModal = true;
    }

    getDayLabel(dayIso) {
        const day = this.weekDays.find(d => d.iso === dayIso);
        return day ? day.label : dayIso;
    }

    formatSlotTime(slot) {
        if (slot.startTime && slot.endTime) {
            let start, end;
            if (typeof slot.startTime === 'string') {
                start = new Date(slot.startTime);
                end = new Date(slot.endTime);
            } else {
                start = slot.startTime;
                end = slot.endTime;
            }
            const sh = String(start.getHours()).padStart(2, '0');
            const sm = String(start.getMinutes()).padStart(2, '0');
            const eh = String(end.getHours()).padStart(2, '0');
            const em = String(end.getMinutes()).padStart(2, '0');
            return `${sh}:${sm} - ${eh}:${em}`;
        }
        if (slot.label) {
            return slot.label;
        }
        return 'N/A';
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
        
        if (!this.appointmentRequestId && !this.currentUserId) {
            this.showToast('Error', 'Appointment request information is required. Please use the link provided in your email.', 'error');
            return;
        }

        this.bookingInProgress = true;
        bookTimeSlot({ 
            timeSlotId: this.selectedSlot.id, 
            customerId: this.currentUserId,
            appointmentRequestId: this.appointmentRequestId
        })
        .then(result => {
            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.handleCloseModal();
                this.fetchTimeslotsForWeek();
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

    get JSONMAP(){
        return JSON.stringify(this.timeslotsMap);
    }
}

