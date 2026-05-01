import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getActiveWorkOrders from '@salesforce/apex/MobileReceiptController.getActiveWorkOrders';
import getExpenses from '@salesforce/apex/MobileReceiptController.getExpenses';
import createWorkOrder from '@salesforce/apex/MobileReceiptController.createWorkOrder';
import createExpense from '@salesforce/apex/MobileReceiptController.createExpense';
import uploadReceiptFile from '@salesforce/apex/MobileReceiptController.uploadReceiptFile';

export default class MobileReceiptCapture extends NavigationMixin(LightningElement) {
    @track currentStep = 1;
    @track selectedAccountId = '';
    @track selectedAccountName = '';
    @track selectedWorkOrderId = '';
    @track selectedWorkOrderNumber = '';
    @track selectedExpenseId = '';
    @track selectedExpenseName = '';
    @track workOrders = [];
    @track expenses = [];
    @track capturedImage = null;
    @track capturedImageName = '';
    @track isLoading = false;
    @track showNewWorkOrderModal = false;
    @track showNewExpenseModal = false;
    
    newWorkOrderSubject = '';
    newWorkOrderDescription = '';
    newExpenseAmount = 0;
    newExpenseDescription = '';
    newExpenseTransactionDate = '';

    get stepTitle() {
        const titles = {
            1: 'Select Account',
            2: 'Select Work Order',
            3: 'Select Expense',
            4: 'Capture Receipt'
        };
        return titles[this.currentStep];
    }

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }

    get progressStyle() {
        return `width: ${(this.currentStep / 4) * 100}%`;
    }

    get canProceedStep1() {
        return this.selectedAccountId !== '';
    }

    get canProceedStep2() {
        return this.selectedWorkOrderId !== '';
    }

    get canProceedStep3() {
        return this.selectedExpenseId !== '';
    }

    get hasWorkOrders() {
        return this.workOrders && this.workOrders.length > 0;
    }

    get hasExpenses() {
        return this.expenses && this.expenses.length > 0;
    }

    get hasCapturedImage() {
        return this.capturedImage !== null;
    }

    handleAccountSelection(event) {
        this.selectedAccountId = event.detail.recordId;
        this.selectedAccountName = event.detail.value && event.detail.value.length > 0 ? event.detail.value[0] : '';
    }

    nextToWorkOrders() {
        if (!this.canProceedStep1) {
            this.showToast('Error', 'Please select an account', 'error');
            return;
        }
        
        this.isLoading = true;
        getActiveWorkOrders({ accountId: this.selectedAccountId })
            .then(result => {
                this.workOrders = result.map(wo => ({
                    id: wo.Id,
                    number: wo.WorkOrderNumber,
                    subject: wo.Subject,
                    status: wo.Status,
                    isSelected: false
                }));
                this.currentStep = 2;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load work orders: ' + this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    selectWorkOrder(event) {
        const workOrderId = event.currentTarget.dataset.id;
        const workOrder = this.workOrders.find(wo => wo.id === workOrderId);
        this.selectedWorkOrderId = workOrderId;
        this.selectedWorkOrderNumber = workOrder.number;
        
        this.workOrders = this.workOrders.map(wo => ({
            ...wo,
            isSelected: wo.id === workOrderId
        }));
    }

    openNewWorkOrderModal() {
        this.showNewWorkOrderModal = true;
    }

    closeNewWorkOrderModal() {
        this.showNewWorkOrderModal = false;
        this.newWorkOrderSubject = '';
        this.newWorkOrderDescription = '';
    }

    handleNewWorkOrderSubject(event) {
        this.newWorkOrderSubject = event.target.value;
    }

    handleNewWorkOrderDescription(event) {
        this.newWorkOrderDescription = event.target.value;
    }

    createNewWorkOrder() {
        if (!this.newWorkOrderSubject) {
            this.showToast('Error', 'Please enter a subject', 'error');
            return;
        }

        this.isLoading = true;
        createWorkOrder({
            accountId: this.selectedAccountId,
            subject: this.newWorkOrderSubject,
            description: this.newWorkOrderDescription
        })
            .then(result => {
                this.selectedWorkOrderId = result.Id;
                this.selectedWorkOrderNumber = result.WorkOrderNumber;
                this.closeNewWorkOrderModal();
                this.showToast('Success', 'Work Order created successfully', 'success');
                this.nextToExpenses();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to create work order: ' + this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    nextToExpenses() {
        if (!this.canProceedStep2) {
            this.showToast('Error', 'Please select a work order', 'error');
            return;
        }

        this.isLoading = true;
        getExpenses({ workOrderId: this.selectedWorkOrderId })
            .then(result => {
                this.expenses = result.map(exp => ({
                    id: exp.Id,
                    name: exp.Title,
                    amount: exp.Amount,
                    description: exp.Description,
                    transactionDate: exp.TransactionDate,
                    isSelected: false
                }));
                this.currentStep = 3;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load expenses: ' + this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    selectExpense(event) {
        const expenseId = event.currentTarget.dataset.id;
        const expense = this.expenses.find(exp => exp.id === expenseId);
        this.selectedExpenseId = expenseId;
        this.selectedExpenseName = expense.name;
        
        this.expenses = this.expenses.map(exp => ({
            ...exp,
            isSelected: exp.id === expenseId
        }));
    }

    openNewExpenseModal() {
        this.showNewExpenseModal = true;
        this.newExpenseTransactionDate = new Date().toISOString().split('T')[0];
    }

    closeNewExpenseModal() {
        this.showNewExpenseModal = false;
        this.newExpenseAmount = 0;
        this.newExpenseDescription = '';
        this.newExpenseTransactionDate = '';
    }

    handleNewExpenseAmount(event) {
        this.newExpenseAmount = event.target.value;
    }

    handleNewExpenseDescription(event) {
        this.newExpenseDescription = event.target.value;
    }

    handleNewExpenseDate(event) {
        this.newExpenseTransactionDate = event.target.value;
    }

    createNewExpense() {
        if (!this.newExpenseAmount || this.newExpenseAmount <= 0) {
            this.showToast('Error', 'Please enter a valid amount', 'error');
            return;
        }

        this.isLoading = true;
        createExpense({
            workOrderId: this.selectedWorkOrderId,
            amount: this.newExpenseAmount,
            description: this.newExpenseDescription,
            transactionDate: this.newExpenseTransactionDate
        })
            .then(result => {
                this.selectedExpenseId = result.Id;
                this.selectedExpenseName = result.Title;
                this.closeNewExpenseModal();
                this.showToast('Success', 'Expense created successfully', 'success');
                this.nextToReceipt();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to create expense: ' + this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    nextToReceipt() {
        if (!this.canProceedStep3) {
            this.showToast('Error', 'Please select an expense', 'error');
            return;
        }
        this.currentStep = 4;
    }

    handleCameraCapture() {
        const input = this.template.querySelector('input[type="file"][data-source="camera"]');
        if (input) {
            input.click();
        }
    }

    handleGallerySelect() {
        const input = this.template.querySelector('input[type="file"][data-source="gallery"]');
        if (input) {
            input.click();
        }
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            if (!file.type.startsWith('image/')) {
                this.showToast('Error', 'Please select an image file', 'error');
                return;
            }

            const reader = new FileReader();
            reader.onload = () => {
                this.capturedImage = reader.result;
                this.capturedImageName = file.name;
            };
            reader.readAsDataURL(file);
        }
    }

    retakePhoto() {
        this.capturedImage = null;
        this.capturedImageName = '';
    }

    uploadReceipt() {
        if (!this.capturedImage) {
            this.showToast('Error', 'Please capture or select a receipt image', 'error');
            return;
        }

        this.isLoading = true;
        const base64Data = this.capturedImage.split(',')[1];
        
        uploadReceiptFile({
            expenseId: this.selectedExpenseId,
            fileName: this.capturedImageName,
            base64Data: base64Data,
            contentType: 'image/jpeg'
        })
            .then(() => {
                this.showToast('Success', 'Receipt uploaded successfully!', 'success');
                this.navigateToExpense();
            })
            .catch(error => {
                this.showToast('Error', 'Failed to upload receipt: ' + this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    navigateToExpense() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.selectedExpenseId,
                objectApiName: 'Expense',
                actionName: 'view'
            }
        });
    }

    previousStep() {
        if (this.currentStep > 1) {
            this.currentStep--;
        }
    }

    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        }
        return 'Unknown error occurred';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}