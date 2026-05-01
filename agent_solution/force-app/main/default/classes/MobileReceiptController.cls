public with sharing class MobileReceiptController {
    
    /**
     * Get active work orders for an account
     */
    @AuraEnabled(cacheable=true)
    public static List<WorkOrder> getActiveWorkOrders(String accountId) {
        try {
            return [
                SELECT Id, WorkOrderNumber, Subject, Status, Address
                FROM WorkOrder
                WHERE AccountId = :accountId
                AND StatusCategory IN ('New', 'InProgress')
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching work orders: ' + e.getMessage());
        }
    }
    
    /**
     * Get expenses for a work order
     */
    @AuraEnabled(cacheable=true)
    public static List<Expense> getExpenses(String workOrderId) {
        try {
            return [
                SELECT Id, Title, Amount, Description, TransactionDate
                FROM Expense
                WHERE WorkOrderId = :workOrderId
                ORDER BY TransactionDate DESC
                LIMIT 50
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching expenses: ' + e.getMessage());
        }
    }
    
    /**
     * Create a new work order
     */
    @AuraEnabled
    public static WorkOrder createWorkOrder(String accountId, String subject, String description) {
        try {
            WorkOrder wo = new WorkOrder(
                AccountId = accountId,
                Subject = subject,
                Description = description,
                Status = 'New'
            );
            insert wo;
            
            // Query the created work order to get the auto-generated WorkOrderNumber
            return [
                SELECT Id, WorkOrderNumber, Subject, Status
                FROM WorkOrder
                WHERE Id = :wo.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error creating work order: ' + e.getMessage());
        }
    }
    
    /**
     * Create a new expense
     */
    @AuraEnabled
    public static Expense createExpense(String workOrderId, Decimal amount, String description, Date transactionDate) {
        try {
            Expense exp = new Expense(
                WorkOrderId = workOrderId,
                Amount = amount,
                Description = description,
                TransactionDate = transactionDate,
                Title = description != null && description.length() > 0 ? description : 'Expense'
            );
            insert exp;
            
            // Query the created expense to get the Title
            return [
                SELECT Id, Title, Amount, Description, TransactionDate
                FROM Expense
                WHERE Id = :exp.Id
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error creating expense: ' + e.getMessage());
        }
    }
    
    /**
     * Upload receipt file and attach to expense
     */
    @AuraEnabled
    public static String uploadReceiptFile(String expenseId, String fileName, String base64Data, String contentType) {
        try {
            // Create ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = expenseId;
            cv.IsMajorVersion = true;
            insert cv;
            
            // Get the ContentDocumentId
            ContentVersion insertedCV = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :cv.Id 
                LIMIT 1
            ];
            
            return insertedCV.ContentDocumentId;
        } catch (Exception e) {
            throw new AuraHandledException('Error uploading receipt: ' + e.getMessage());
        }
    }
}