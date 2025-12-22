import { LightningElement, track } from 'lwc';
import uploadCSV from '@salesforce/apex/AppointmentRequestController.uploadCSV';
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
            
            // Call Apex to process CSV
            const result = await uploadCSV({
                csvContent: fileContent
            });

            if (result.success) {
                this.showToast('Success', 
                    `${result.recordsCreated} Appointment Request(s) created successfully. ${result.emailsSent} email(s) sent.`, 
                    'success');
                this.handleCloseModal();
                
                // Dispatch event to refresh parent component if needed
                this.dispatchEvent(new CustomEvent('uploadsuccess'));
            } else {
                this.showToast('Error', result.message, 'error');
            }
        } catch (error) {
            console.error('Error uploading CSV:', error);
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

    isValidEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
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

