import { LightningElement, track } from 'lwc';
import createTimeSlotsFromCSV from '@salesforce/apex/VolunteerAvailabilityController.createTimeSlotsFromCSV';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class VolunteerAvailabilityUploader extends LightningElement {
    @track showModal = false;
    @track selectedFile;
    @track uploading = false;
    @track fileName = '';

    handleOpenModal() {
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
        this.selectedFile = null;
        this.fileName = '';
        const fileInput = this.template.querySelector('lightning-input[type="file"]');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            if (file.type !== 'text/csv' && !file.name.endsWith('.csv')) {
                this.showToast('Error', 'Please upload a CSV file', 'error');
                return;
            }
            this.selectedFile = file;
            this.fileName = file.name;
        }
    }

    async handleUpload() {
        if (!this.selectedFile) {
            this.showToast('Error', 'Please select a CSV file', 'error');
            return;
        }

        this.uploading = true;

        try {
            const fileContent = await this.readFileContent(this.selectedFile);
            
            const validationResult = this.validateCSVContent(fileContent);
            if (!validationResult.isValid) {
                this.showToast('Validation Error', validationResult.message, 'error');
                this.uploading = false;
                return;
            }
            
            const result = await createTimeSlotsFromCSV({
                csvContent: fileContent
            });

            if (result.success) {
                // Check if there were warnings (e.g., volunteer not found)
                if (result.warnings && result.warnings.length > 0) {
                    const emailList = result.warnings.slice(0, 3).join(', ');
                    const suffix = result.warnings.length > 3 ? ` (+${result.warnings.length - 3} more)` : '';
                    
                    if (result.slotsCreated === 0) {
                        // No slots created - treat as error
                        this.showToast('Error', 
                            `No slots created. Volunteers not found: ${emailList}${suffix}`, 
                            'error');
                    } else {
                        // Some slots created - partial success
                        this.showToast('Partial Success', 
                            `No Volunteers could be found with the following emails: ${emailList}${suffix}`, 
                            'warning');
                        this.handleCloseModal();
                        this.dispatchEvent(new CustomEvent('uploadsuccess'));
                    }
                } else {
                    this.showToast('Success', result.message, 'success');
                    this.handleCloseModal();
                    this.dispatchEvent(new CustomEvent('uploadsuccess'));
                }
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Error', 
                'Error processing CSV: ' + (error.body?.message || error.message || 'Unknown error'), 
                'error');
        } finally {
            this.uploading = false;
        }
    }

    readFileContent(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => {
                resolve(e.target.result);
            };
            reader.onerror = (error) => {
                reject(error);
            };
            reader.readAsText(file);
        });
    }

    validateCSVContent(csvContent) {
        if (!csvContent || csvContent.trim().length === 0) {
            return { isValid: false, message: 'CSV file is empty' };
        }
        
        const lines = csvContent.split('\n').filter(line => line.trim().length > 0);
        if (lines.length === 0) {
            return { isValid: false, message: 'CSV file contains no data' };
        }
        
        const firstLine = lines[0].trim().toLowerCase();
        let startIndex = 0;
        if (firstLine.includes('volunteer') || firstLine.includes('email') || 
            firstLine.includes('day') || firstLine.includes('date') ||
            firstLine.includes('start') || firstLine.includes('end') ||
            firstLine.includes('time')) {
            startIndex = 1;
        }
        
        if (lines.length <= startIndex) {
            return { isValid: false, message: 'CSV file contains no data rows (only header or empty)' };
        }
        
        let errors = [];
        for (let i = startIndex; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0) continue;
            
            const rowNum = i + 1;
            const columns = this.parseCSVLine(line);
            
            // Check column count
            if (columns.length < 4) {
                errors.push(`Row ${rowNum}: Expected 4 columns, found ${columns.length}`);
                continue;
            }
            
            const [email, day, startTime, endTime] = columns.map(c => c.trim());
            
            // Check required fields
            if (!email) {
                errors.push(`Row ${rowNum}: Volunteer email is empty`);
                continue;
            }
            
            // Validate date format (YYYY-MM-DD)
            if (!this.isValidDateFormat(day)) {
                errors.push(`Row ${rowNum}: Invalid date format "${day}" (expected YYYY-MM-DD)`);
                continue;
            }
            
            // Validate time formats (HH:mm)
            if (!this.isValidTimeFormat(startTime)) {
                errors.push(`Row ${rowNum}: Invalid start time "${startTime}" (expected HH:mm)`);
                continue;
            }
            
            if (!this.isValidTimeFormat(endTime)) {
                errors.push(`Row ${rowNum}: Invalid end time "${endTime}" (expected HH:mm)`);
                continue;
            }
        }
        
        if (errors.length > 0) {
            // Show first 3 errors to keep message manageable
            const displayErrors = errors.slice(0, 3).join('; ');
            const suffix = errors.length > 3 ? ` (+${errors.length - 3} more errors)` : '';
            return { isValid: false, message: displayErrors + suffix };
        }
        
        return { isValid: true, message: '' };
    }

    parseCSVLine(line) {
        const values = [];
        let inQuotes = false;
        let currentValue = '';
        
        for (let i = 0; i < line.length; i++) {
            const char = line[i];
            if (char === '"') {
                inQuotes = !inQuotes;
            } else if (char === ',' && !inQuotes) {
                values.push(currentValue);
                currentValue = '';
            } else {
                currentValue += char;
            }
        }
        values.push(currentValue);
        return values;
    }

    isValidDateFormat(dateStr) {
        if (!dateStr) return false;
        const parts = dateStr.split('-');
        if (parts.length !== 3) return false;
        
        const [year, month, day] = parts.map(p => parseInt(p, 10));
        if (isNaN(year) || isNaN(month) || isNaN(day)) return false;
        if (year < 2000 || year > 2100) return false;
        if (month < 1 || month > 12) return false;
        if (day < 1 || day > 31) return false;
        
        return true;
    }

    isValidTimeFormat(timeStr) {
        if (!timeStr) return false;
        const parts = timeStr.split(':');
        if (parts.length !== 2) return false;
        
        const [hours, minutes] = parts.map(p => parseInt(p, 10));
        if (isNaN(hours) || isNaN(minutes)) return false;
        if (hours < 0 || hours > 23) return false;
        if (minutes < 0 || minutes > 59) return false;
        
        return true;
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }
}

