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
        // Reset file input
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
            // Read file content
            const fileContent = await this.readFileContent(this.selectedFile);
            
            // Validate CSV format before submitting
            const validationResult = this.validateCSVContent(fileContent);
            if (!validationResult.isValid) {
                this.showToast('Validation Error', validationResult.message, 'error');
                this.uploading = false;
                return;
            }
            
            // Call Apex to process CSV
            const result = await createTimeSlotsFromCSV({
                csvContent: fileContent
            });

            if (result.success) {
                this.showToast('Success', 
                    result.message, 
                    'success');
                this.handleCloseModal();
                
                // Dispatch event to refresh parent component if needed
                this.dispatchEvent(new CustomEvent('uploadsuccess'));
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
        
        // Check if first line looks like a header (optional)
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
        
        // Validate that each row has at least 4 columns
        let invalidRows = [];
        for (let i = startIndex; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.length === 0) continue;
            
            // Simple CSV parsing - count commas (assuming no quoted values with commas)
            const columns = line.split(',');
            if (columns.length < 4) {
                invalidRows.push(i + 1);
            }
        }
        
        if (invalidRows.length > 0) {
            return { 
                isValid: false, 
                message: `Rows ${invalidRows.join(', ')} do not have the required 4 columns (Volunteer Email, Day, Start Time, End Time)` 
            };
        }
        
        return { isValid: true, message: '' };
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

