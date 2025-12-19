import { LightningElement, track } from 'lwc';
import getTimeslotsForRange from '@salesforce/apex/TimeslotController.getTimeslotsForRange';

export default class TimeslotGrid extends LightningElement {
    @track loading = true;

    // Selected date default = today + 7 days
    selectedDate;

    // weekDays: array of {date: Date obj, iso: 'YYYY-MM-DD', label: 'Mon 12/01'}
    @track weekDays = [];

    // timeslotsMap: { 'YYYY-MM-DD': { 'HH:mm': { id, startTime, endTime, numberAvailable } } }
    timeslotsMap = {};

    @track timeRows = []; // list of time labels like '09:00'

    connectedCallback() {
        const today = new Date();
        const defaultDate = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 7);
        this.selectedDate = defaultDate;
        this.selectedDateISO = this.toISODate(this.selectedDate);
        this.buildWeekFromSelectedDate();
        this.fetchTimeslotsForWeek();
    }

    // helper to produce 'YYYY-MM-DD' string
    toISODate(dateObj) {
        const yyyy = dateObj.getFullYear();
        const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
        const dd = String(dateObj.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    // when date picker changes
    handleDateChange(event) {
        const iso = event.target.value;
        if (iso) {
            this.selectedDateISO = iso;
            // build JS Date from iso (YYYY-MM-DD)
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

    // Build Monday-Friday week that contains selectedDate
    buildWeekFromSelectedDate() {
        this.weekDays = [];
        const sel = new Date(this.selectedDate.getFullYear(), this.selectedDate.getMonth(), this.selectedDate.getDate());
        // compute Monday of the week (ISO week Monday)
        const dayOfWeek = sel.getDay(); // 0 = Sun, 1 = Mon, ...
        // compute difference to Monday
        const diffToMonday = (dayOfWeek === 0) ? -6 : (1 - dayOfWeek);
        const mondayDate = new Date(sel.getFullYear(), sel.getMonth(), sel.getDate() + diffToMonday);
        // create Monday through Friday
        for (let i = 0; i < 5; i++) {
            const d = new Date(mondayDate.getFullYear(), mondayDate.getMonth(), mondayDate.getDate() + i);
            this.weekDays.push({
                date: d,
                iso: this.toISODate(d),
                label: d.toLocaleDateString(undefined, { weekday: 'short', month: 'numeric', day: 'numeric' })
            });
        }
    }

    // Fetch timeslots from server
    fetchTimeslotsForWeek() {
        this.loading = true;
        // compute start and end dates as ISO strings; Apex expects Date so pass as 'YYYY-MM-DD'
        const startIso = this.weekDays[0].iso;
        const endIso = this.weekDays[this.weekDays.length - 1].iso;
        getTimeslotsForRange({ startDate: startIso, endDate: endIso })
            .then(result => {
                // result is a list of wrapper records: { id, startTime, endTime, day, numberAvailable }
                this.timeslotsMap = {};
                // Build row times set
                const timeSet = new Set();
                this.timeslotsMap = result;
                /*result.forEach(item => {
                    if (!item.day) return;
                    // day is ISO yyyy-MM-dd from Apex deserialization
                    const dayIso = item.day;
                    // Compute slot label based on startTime (Datetime string). Convert to local time string HH:mm
                    const dt = new Date(item.startTime);
                    const hh = String(dt.getHours()).padStart(2, '0');
                    const mm = String(dt.getMinutes()).padStart(2, '0');
                    const timeLabel = `${hh}:${mm}`;
                    timeSet.add(timeLabel);
                    if (!this.timeslotsMap[dayIso]) {
                        this.timeslotsMap[dayIso] = {};
                    }
                    this.timeslotsMap[dayIso][timeLabel] = {
                        id: item.id,
                        startTime: item.startTime,
                        endTime: item.endTime,
                        numberAvailable: item.numberAvailable
                    };
                });

                // sort times ascending and set timeRows
                const sortedTimes = Array.from(timeSet).sort((a, b) => {
                    // compare HH:MM strings
                    return a.localeCompare(b);
                });
                this.timeRows = sortedTimes;

                // If there are no times returned, optionally build a default schedule (e.g., 9:00..17:00 @ 20min). Build if timeRows empty
                if (this.timeRows.length === 0) {
                    this.timeRows = this.buildDefaultTimeRows();
                }*/
            })
            .catch(error => {
                // handle error - show no slots
                console.error('Error fetching timeslots', error);
                this.timeslotsMap = {};
                this.timeRows = this.buildDefaultTimeRows();
            })
            .finally(() => {
                this.loading = false;
            });
    }

    buildDefaultTimeRows() {
        // default 09:00 to 16:40 every 20 minutes
        const rows = [];
        for (let h = 9; h < 17; h++) {
            for (let m = 0; m < 60; m += 20) {
                const hh = String(h).padStart(2, '0');
                const mm = String(m).padStart(2, '0');
                // stop if 17:00 exactly (we want last row that starts before 17:00)
                const timeLabel = `${hh}:${mm}`;
                rows.push(timeLabel);
            }
        }
        return rows;
    }

    // Template helpers
    hasSlot(dayIso, timeRow) {
        return this.timeslotsMap && this.timeslotsMap[dayIso] && this.timeslotsMap[dayIso][timeRow];
    }

    getSlotId(dayIso, timeRow) {
        return (this.hasSlot(dayIso, timeRow) ? this.timeslotsMap[dayIso][timeRow].id : null);
    }

    getSlotQty(dayIso, timeRow) {
        return (this.hasSlot(dayIso, timeRow) ? this.timeslotsMap[dayIso][timeRow].numberAvailable : 0);
    }

    formatCellTime(dayIso, timeRow) {
        // Show start-end e.g., 09:00 - 09:20 if end known
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
        const slotId = event.currentTarget.dataset.id;
        if (!slotId) return;
        // The caller can handle the slot selection — for now we simply dispatch an event
        const detail = { slotId };
        this.dispatchEvent(new CustomEvent('slotselected', { detail }));
        // Optionally highlight selection or open modal — left to implement
    }

    get JSONMAP(){
        return JSON.stringify(this.timeslotsMap);
    }
}