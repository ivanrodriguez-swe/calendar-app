import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createTimeSlotsFromRanges from '@salesforce/apex/VolunteerAvailabilityController.createTimeSlotsFromRanges';

export default class VolunteerAvailability extends LightningElement {
    @track availabilityRanges = [];
    @track submitting = false;
    minDate = '';
    currentTime = '';

    connectedCallback() {
        // Set minimum date to today
        const today = new Date();
        this.minDate = this.toISODate(today);
        
        // Set current time (rounded up to next 15-minute interval)
        this.currentTime = this.getCurrentTimeRoundedUp();
        
        // Add one empty range by default
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
        
        // Round up to next 15-minute interval
        minutes = Math.ceil(minutes / 15) * 15;
        if (minutes >= 60) {
            minutes = 0;
            hours += 1;
        }
        
        // Format as HH:mm
        return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
    }

    getMinTimeForDate(dateValue) {
        if (!dateValue) {
            return '09:00'; // Default minimum
        }
        
        const today = this.toISODate(new Date());
        if (dateValue === today) {
            // If date is today, use current time rounded up to next 15-minute interval
            // or 09:00, whichever is later
            // currentTime is already rounded up to next 15-minute interval
            const currentTimeMinutes = this.timeToMinutes(this.currentTime);
            const minTimeMinutes = 9 * 60; // 9:00 AM
            const minMinutes = Math.max(currentTimeMinutes, minTimeMinutes);
            const hours = Math.floor(minMinutes / 60);
            const mins = minMinutes % 60;
            return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
        }
        return '09:00'; // For future dates, use 9:00 AM
    }

    getMinEndTimeForDate(dateValue, startTime) {
        if (!dateValue) {
            return '09:15'; // Default minimum
        }
        
        const today = this.toISODate(new Date());
        const currentTimeMinutes = this.timeToMinutes(this.currentTime);
        
        // If we have a start time, the minimum end time should be based on the start time
        if (startTime) {
            const startMinutes = this.timeToMinutes(startTime);
            let minEndMinutes = startMinutes + 15; // At least 15 minutes after start
            
            // If date is today, also ensure end time is not in the past
            if (dateValue === today) {
                minEndMinutes = Math.max(minEndMinutes, currentTimeMinutes + 15);
            }
            
            // Ensure minimum is at least 9:15 AM
            minEndMinutes = Math.max(minEndMinutes, 9 * 60 + 15);
            const hours = Math.floor(minEndMinutes / 60);
            const mins = minEndMinutes % 60;
            return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
        }
        
        // No start time yet - use current time if today, otherwise 9:15 AM
        if (dateValue === today) {
            const minEndMinutes = Math.max(currentTimeMinutes + 15, 9 * 60 + 15);
            const hours = Math.floor(minEndMinutes / 60);
            const mins = minEndMinutes % 60;
            return `${String(hours).padStart(2, '0')}:${String(mins).padStart(2, '0')}`;
        }
        
        return '09:15'; // Default minimum for future dates
    }

    addTimeRange() {
        this.availabilityRanges = [...this.availabilityRanges, {
            id: Date.now() + Math.random(), // Unique ID for each range
            date: '',
            startTime: '',
            endTime: '',
            minStartTime: '09:00',
            minEndTime: '09:15'
        }];
    }

    removeTimeRange(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        
        // Prevent deleting if only one range exists
        if (this.availabilityRanges.length <= 1) {
            this.showToast('Warning', 'You must have at least one time range', 'warning');
            return;
        }
        
        // Convert both to strings for comparison to handle type mismatch
        const rangeIdStr = String(rangeId);
        this.availabilityRanges = this.availabilityRanges.filter(
            range => String(range.id) !== rangeIdStr
        );
    }

    handleDateChange(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        const dateValue = event.target.value;
        this.updateRange(rangeId, 'date', dateValue);
        
        // Check if date is today and validate business hours
        this.validateTodayDate(dateValue, rangeId);
        
        // Update min times based on the selected date
        this.updateMinTimes(rangeId, dateValue);
        
        // Check for duplicates after date change
        this.checkForDuplicates(rangeId);
    }
    
    validateTodayDate(dateValue, rangeId) {
        const today = this.toISODate(new Date());
        if (dateValue === today) {
            const now = new Date();
            const currentHours = now.getHours();
            const currentMinutes = now.getMinutes();
            const currentTimeMinutes = currentHours * 60 + currentMinutes;
            const endOfBusinessMinutes = 16 * 60; // 4:00 PM = 960 minutes
            
            // Check if it's past 4 PM
            if (currentTimeMinutes >= endOfBusinessMinutes) {
                this.showToast('Date Selection', 
                    'It is past 4:00 PM today. Please select a different date to set availability.', 
                    'warning');
                return;
            }
            
            // Check if less than 15 minutes remain until 4 PM
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
        
        // Update min end time based on start time
        const range = this.availabilityRanges.find(r => String(r.id) === String(rangeId));
        if (range) {
            const minEndTime = this.getMinEndTimeForDate(range.date, timeValue);
            this.updateRange(rangeId, 'minEndTime', minEndTime);
        }
        
        // Check for duplicates after start time change
        this.checkForDuplicates(rangeId);
    }

    handleEndTimeChange(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        const timeValue = event.target.value;
        this.updateRange(rangeId, 'endTime', timeValue);
        
        // Check for duplicates after end time change
        this.checkForDuplicates(rangeId);
    }
    
    checkForDuplicates(currentRangeId) {
        const rangeIdStr = String(currentRangeId);
        const currentRange = this.availabilityRanges.find(r => String(r.id) === rangeIdStr);
        
        if (!currentRange || !currentRange.date || !currentRange.startTime || !currentRange.endTime) {
            return; // Can't check duplicates if range is incomplete
        }
        
        const currentKey = `${currentRange.date}|${currentRange.startTime}|${currentRange.endTime}`;
        const duplicateRanges = this.availabilityRanges.filter((range, index) => {
            if (String(range.id) === rangeIdStr) {
                return false; // Skip the current range
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
        // Convert to string for comparison to handle type mismatch
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
        
        // Business hours: 9:00 AM (09:00) to 4:00 PM (16:00)
        const MIN_START_TIME_MINUTES = 9 * 60; // 9:00 AM = 540 minutes (earliest start time)
        const MIN_END_TIME_MINUTES = 9 * 60 + 15; // 9:15 AM = 555 minutes (earliest end time, 15 min after earliest start)
        const MAX_START_TIME_MINUTES = 15 * 60 + 45; // 3:45 PM = 945 minutes (last valid start time)
        const MAX_END_TIME_MINUTES = 16 * 60; // 4:00 PM = 960 minutes (latest end time)
        
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
        const endOfBusinessMinutes = 16 * 60; // 4:00 PM = 960 minutes

        // Check for duplicate ranges (same date, start time, and end time)
        const rangeKeys = new Map(); // Map to track range keys and their indices
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
                // Validate date is not in the past
                if (range.date < today) {
                    errors.push(`Range ${index + 1}: Date cannot be in the past`);
                }
                
                // If date is today, check if it's past 4 PM or less than 15 minutes remain
                if (range.date === today) {
                    // Check if it's past 4 PM
                    if (actualCurrentTimeMinutes >= endOfBusinessMinutes) {
                        errors.push(`Range ${index + 1}: It is past 4:00 PM today. Please select a different date to set availability.`);
                    } else {
                        // Check if less than 15 minutes remain until 4 PM
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
                // Convert time strings to comparable format
                // HTML5 time input uses 24-hour format (00:00 to 23:59)
                const start = this.timeToMinutes(range.startTime);
                const end = this.timeToMinutes(range.endTime);
                
                // Validate that end time is at least 15 minutes after start time
                if (end < start + 15) {
                    errors.push(`Range ${index + 1}: End time must be at least 15 minutes after start time`);
                }
                
                // If date is today, validate start time is not in the past
                if (range.date === today) {
                    if (start < currentTimeMinutes) {
                        errors.push(`Range ${index + 1}: Start time cannot be in the past`);
                    }
                }
                
                // Validate start time is within business hours (9:00 AM to 3:45 PM)
                // Last start time is 3:45 PM to allow a 15-minute slot ending at 4:00 PM
                if (start < MIN_START_TIME_MINUTES || start > MAX_START_TIME_MINUTES) {
                    errors.push(`Range ${index + 1}: Start time must be between 9:00 AM and 3:45 PM`);
                }
                // Validate end time is within business hours (9:15 AM to 4:00 PM)
                // First end time is 9:15 AM (15 minutes after earliest start time of 9:00 AM)
                if (end < MIN_END_TIME_MINUTES || end > MAX_END_TIME_MINUTES) {
                    errors.push(`Range ${index + 1}: End time must be between 9:15 AM and 4:00 PM`);
                }
            }
        });

        return errors;
    }

    timeToMinutes(timeString) {
        // Convert "HH:mm" format to minutes since midnight
        const parts = timeString.split(':');
        return parseInt(parts[0]) * 60 + parseInt(parts[1]);
    }

    handleSubmit() {
        // Validate all ranges
        const errors = this.validateRanges();
        if (errors.length > 0) {
            this.showToast('Validation Error', errors.join('; '), 'error');
            return;
        }

        // Prepare data for Apex
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
                    // Clear all ranges and add a new empty one
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

