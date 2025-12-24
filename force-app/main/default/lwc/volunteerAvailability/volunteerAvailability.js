import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createTimeSlotsFromRanges from '@salesforce/apex/VolunteerAvailabilityController.createTimeSlotsFromRanges';

export default class VolunteerAvailability extends LightningElement {
    @track availabilityRanges = [];
    @track submitting = false;
    minDate = '';
    currentTime = '';

    connectedCallback() {
        const today = new Date();
        this.minDate = this.toISODate(today);
        
        this.currentTime = this.getCurrentTimeRoundedUp();
        
        this.addTimeRange();
    }

    toISODate(dateObj) {
        const yyyy = dateObj.getFullYear();
        const mm = String(dateObj.getMonth() + 1).padStart(2, '0');
        const dd = String(dateObj.getDate()).padStart(2, '0');
        return `${yyyy}-${mm}-${dd}`;
    }

    getCurrentTimeRoundedUp() {
        const now = new Date();
        let hours = now.getHours();
        let minutes = now.getMinutes();
        
        minutes = Math.ceil(minutes / 15) * 15;
        if (minutes >= 60) {
            minutes = 0;
            hours += 1;
        }
        
        return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
    }

    getMinTimeForDate(dateValue) {
        if (!dateValue) {
            return '09:00';
        }
        
        const today = this.toISODate(new Date());
        if (dateValue === today) {
            const currentTimeMinutes = this.timeToMinutes(this.currentTime);
            const minTimeMinutes = 9 * 60;
            const minMinutes = Math.max(currentTimeMinutes, minTimeMinutes);
            const hours = Math.floor(minMinutes / 60);
            const mins = minMinutes % 60;
            return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
        }
        return '09:00';
    }

    getMinEndTimeForDate(dateValue, startTime) {
        if (!dateValue) {
            return '09:15';
        }
        
        const today = this.toISODate(new Date());
        const currentTimeMinutes = this.timeToMinutes(this.currentTime);
        
        if (startTime) {
            const startMinutes = this.timeToMinutes(startTime);
            let minEndMinutes = startMinutes + 15;
            
            if (dateValue === today) {
                minEndMinutes = Math.max(minEndMinutes, currentTimeMinutes + 15);
            }
            
            minEndMinutes = Math.max(minEndMinutes, 9 * 60 + 15);
            const hours = Math.floor(minEndMinutes / 60);
            const mins = minEndMinutes % 60;
            return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
        }
        
        if (dateValue === today) {
            const minEndMinutes = Math.max(currentTimeMinutes + 15, 9 * 60 + 15);
            const hours = Math.floor(minEndMinutes / 60);
            const mins = minEndMinutes % 60;
            return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
        }
        
        return '09:15';
    }

    addTimeRange() {
        this.availabilityRanges = [...this.availabilityRanges, {
            id: Date.now() + Math.random(),
            date: '',
            startTime: '',
            endTime: '',
            minStartTime: '09:00',
            minEndTime: '09:15'
        }];
    }

    removeTimeRange(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        
        if (this.availabilityRanges.length <= 1) {
            this.showToast('Warning', 'You must have at least one time range', 'warning');
            return;
        }
        
        const rangeIdStr = String(rangeId);
        this.availabilityRanges = this.availabilityRanges.filter(
            range => String(range.id) !== rangeIdStr
        );
    }

    handleDateChange(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        const dateValue = event.target.value;
        this.updateRange(rangeId, 'date', dateValue);
        
        this.validateTodayDate(dateValue, rangeId);
        
        this.updateMinTimes(rangeId, dateValue);
        
        this.checkForDuplicates(rangeId);
    }
    
    validateTodayDate(dateValue, rangeId) {
        const today = this.toISODate(new Date());
        if (dateValue === today) {
            const now = new Date();
            const currentHours = now.getHours();
            const currentMinutes = now.getMinutes();
            const currentTimeMinutes = currentHours * 60 + currentMinutes;
            const endOfBusinessMinutes = 16 * 60;
            
            if (currentTimeMinutes >= endOfBusinessMinutes) {
                this.showToast('Date Selection', 
                    'It is past 4:00 PM today. Please select a different date to set availability.', 
                    'warning');
                return;
            }
            
            const minutesUntil4PM = endOfBusinessMinutes - currentTimeMinutes;
            if (minutesUntil4PM < 15) {
                this.showToast('Date Selection', 
                    `Only ${minutesUntil4PM} minute(s) remain until 4:00 PM today. Please select a different date to set availability.`, 
                    'warning');
                return;
            }
        }
    }

    updateMinTimes(rangeId, dateValue) {
        const rangeIdStr = String(rangeId);
        const minStartTime = this.getMinTimeForDate(dateValue);
        const range = this.availabilityRanges.find(r => String(r.id) === rangeIdStr);
        const minEndTime = this.getMinEndTimeForDate(dateValue, range ? range.startTime : '');
        
        this.availabilityRanges = this.availabilityRanges.map(range => {
            if (String(range.id) === rangeIdStr) {
                return { 
                    ...range, 
                    minStartTime: minStartTime,
                    minEndTime: minEndTime
                };
            }
            return range;
        });
    }

    handleStartTimeChange(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        const timeValue = event.target.value;
        this.updateRange(rangeId, 'startTime', timeValue);
        
        const range = this.availabilityRanges.find(r => String(r.id) === String(rangeId));
        if (range) {
            const minEndTime = this.getMinEndTimeForDate(range.date, timeValue);
            this.updateRange(rangeId, 'minEndTime', minEndTime);
        }
        
        this.checkForDuplicates(rangeId);
    }

    handleEndTimeChange(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        const timeValue = event.target.value;
        this.updateRange(rangeId, 'endTime', timeValue);
        
        this.checkForDuplicates(rangeId);
    }
    
    checkForDuplicates(currentRangeId) {
        const rangeIdStr = String(currentRangeId);
        const currentRange = this.availabilityRanges.find(r => String(r.id) === rangeIdStr);
        
        if (!currentRange || !currentRange.date || !currentRange.startTime || !currentRange.endTime) {
            return;
        }
        
        const currentKey = `${currentRange.date}|${currentRange.startTime}|${currentRange.endTime}`;
        const duplicateRanges = this.availabilityRanges.filter((range, index) => {
            if (String(range.id) === rangeIdStr) {
                return false;
            }
            if (range.date && range.startTime && range.endTime) {
                const rangeKey = `${range.date}|${range.startTime}|${range.endTime}`;
                return rangeKey === currentKey;
            }
            return false;
        });
        
        if (duplicateRanges.length > 0) {
            const duplicateIndices = this.availabilityRanges
                .map((r, idx) => {
                    if (String(r.id) !== rangeIdStr && r.date && r.startTime && r.endTime) {
                        const key = `${r.date}|${r.startTime}|${r.endTime}`;
                        return key === currentKey ? idx + 1 : null;
                    }
                    return null;
                })
                .filter(idx => idx !== null);
            
            if (duplicateIndices.length > 0) {
                this.showToast('Duplicate Range', 
                    `This time range is a duplicate of Range ${duplicateIndices[0]}. Each date/time combination must be unique.`, 
                    'warning');
            }
        }
    }

    updateRange(rangeId, field, value) {
        const rangeIdStr = String(rangeId);
        this.availabilityRanges = this.availabilityRanges.map(range => {
            if (String(range.id) === rangeIdStr) {
                return { ...range, [field]: value };
            }
            return range;
        });
    }

    validateRanges() {
        const errors = [];
        
        const MIN_START_TIME_MINUTES = 9 * 60;
        const MIN_END_TIME_MINUTES = 9 * 60 + 15;
        const MAX_START_TIME_MINUTES = 15 * 60 + 45;
        const MAX_END_TIME_MINUTES = 16 * 60;
        
        if (this.availabilityRanges.length === 0) {
            errors.push('Please add at least one availability range');
            return errors;
        }

        const today = this.toISODate(new Date());
        const currentTimeMinutes = this.timeToMinutes(this.currentTime);
        const now = new Date();
        const currentHours = now.getHours();
        const currentMinutes = now.getMinutes();
        const actualCurrentTimeMinutes = currentHours * 60 + currentMinutes;
        const endOfBusinessMinutes = 16 * 60;

        const rangeKeys = new Map();
        this.availabilityRanges.forEach((range, index) => {
            if (range.date && range.startTime && range.endTime) {
                const rangeKey = `${range.date}|${range.startTime}|${range.endTime}`;
                if (rangeKeys.has(rangeKey)) {
                    const firstIndex = rangeKeys.get(rangeKey);
                    errors.push(`Range ${index + 1} is a duplicate of Range ${firstIndex + 1}. Each date/time combination must be unique.`);
                } else {
                    rangeKeys.set(rangeKey, index);
                }
            }
        });

        this.availabilityRanges.forEach((range, index) => {
            if (!range.date) {
                errors.push(`Range ${index + 1}: Date is required`);
            } else {
                if (range.date < today) {
                    errors.push(`Range ${index + 1}: Date cannot be in the past`);
                }
                
                if (range.date === today) {
                    if (actualCurrentTimeMinutes >= endOfBusinessMinutes) {
                        errors.push(`Range ${index + 1}: It is past 4:00 PM today. Please select a different date to set availability.`);
                    } else {
                        const minutesUntil4PM = endOfBusinessMinutes - actualCurrentTimeMinutes;
                        if (minutesUntil4PM < 15) {
                            errors.push(`Range ${index + 1}: Only ${minutesUntil4PM} minute(s) remain until 4:00 PM today. Please select a different date to set availability.`);
                        }
                    }
                }
            }
            if (!range.startTime) {
                errors.push(`Range ${index + 1}: Start time is required`);
            }
            if (!range.endTime) {
                errors.push(`Range ${index + 1}: End time is required`);
            }
            
            if (range.date && range.startTime && range.endTime) {
                const start = this.timeToMinutes(range.startTime);
                const end = this.timeToMinutes(range.endTime);
                
                if (end < start + 15) {
                    errors.push(`Range ${index + 1}: End time must be at least 15 minutes after start time`);
                }
                
                if (range.date === today) {
                    if (start < currentTimeMinutes) {
                        errors.push(`Range ${index + 1}: Start time cannot be in the past`);
                    }
                }
                
                if (start < MIN_START_TIME_MINUTES || start > MAX_START_TIME_MINUTES) {
                    errors.push(`Range ${index + 1}: Start time must be between 9:00 AM and 3:45 PM`);
                }
                if (end < MIN_END_TIME_MINUTES || end > MAX_END_TIME_MINUTES) {
                    errors.push(`Range ${index + 1}: End time must be between 9:15 AM and 4:00 PM`);
                }
            }
        });

        return errors;
    }

    timeToMinutes(timeString) {
        const parts = timeString.split(':');
        return parseInt(parts[0]) * 60 + parseInt(parts[1]);
    }

    handleSubmit() {
        const errors = this.validateRanges();
        if (errors.length > 0) {
            this.showToast('Validation Error', errors.join('; '), 'error');
            return;
        }

        const rangesToSend = this.availabilityRanges
            .filter(range => range.date && range.startTime && range.endTime)
            .map(range => {
                const rangeObj = {
                    dateValue: range.date,
                    startTime: range.startTime,
                    endTime: range.endTime
                };
                return rangeObj;
            });

        if (rangesToSend.length === 0) {
            this.showToast('Error', 'No valid availability ranges to submit', 'error');
            return;
        }

        
        this.submitting = true;
        createTimeSlotsFromRanges({ ranges: rangesToSend })
            .then(result => {
                if (result.success) {
                    this.showToast('Success', result.message, 'success');
                    this.availabilityRanges = [];
                    this.addTimeRange();
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            })
            .catch(error => {
                const errorMessage = error.body?.message || error.message || 'An error occurred while creating time slots';
                this.showToast('Error', errorMessage, 'error');
            })
            .finally(() => {
                this.submitting = false;
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

    get hasRanges() {
        return this.availabilityRanges && this.availabilityRanges.length > 0;
    }
}

