import { LightningElement, track } from 'lwc';
import processFile from '@salesforce/apex/AppointmentRequestController.processFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AppointmentRequestUploader extends LightningElement {
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
            
            // Validate CSV format before sending to Apex
            const validationResult = this.validateCSVContent(fileContent);
            if (!validationResult.isValid) {
                this.showToast('Validation Error', validationResult.message, 'error');
                this.uploading = false;
                return;
            }
            
            const result = await processFile({
                fileContent: fileContent
            });

            if (result.success) {
                this.showToast('Success', result.message, 'success');
                this.handleCloseModal();
                
                this.dispatchEvent(new CustomEvent('uploadsuccess'));
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            this.showToast('Error', 
                'Error processing file: ' + (error.body?.message || error.message || 'Unknown error'), 
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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
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
        if (firstLine.includes('selectee') || firstLine.includes('first name') || 
            firstLine.includes('last name') || firstLine.includes('reference') ||
            firstLine.includes('discipline') || firstLine.includes('eod')) {
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
            
            // Check minimum column count (5 for Selectee info)
            if (columns.length < 5) {
                errors.push(`Row ${rowNum}: Expected at least 5 columns, found ${columns.length}`);
                continue;
            }
            
            const lastName = columns[0].trim();
            const firstName = columns[1].trim();
            const expectedEOD = columns[3].trim();
            
            // Check required Selectee fields
            if (!lastName || !firstName) {
                errors.push(`Row ${rowNum}: Selectee first name and last name are required`);
                continue;
            }
            
            // Validate EOD date format if provided (YYYY-MM-DD)
            if (expectedEOD && !this.isValidDateFormat(expectedEOD)) {
                errors.push(`Row ${rowNum}: Invalid Expected EOD date "${expectedEOD}" (expected YYYY-MM-DD)`);
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
}
