@isTest
private class MobileReceiptControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create test work order
        WorkOrder testWO = new WorkOrder(
            AccountId = testAccount.Id,
            Subject = 'Test Work Order',
            Description = 'Test Description',
            Status = 'New'
        );
        insert testWO;
        
        // Create test expense
        Expense testExpense = new Expense(
            WorkOrderId = testWO.Id,
            Amount = 100.00,
            Description = 'Test Expense',
            TransactionDate = Date.today()
        );
        insert testExpense;
    }
    
    @isTest
    static void testGetActiveWorkOrders() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<WorkOrder> workOrders = MobileReceiptController.getActiveWorkOrders(testAccount.Id);
        Test.stopTest();
        
        System.assertEquals(1, workOrders.size(), 'Should return 1 work order');
        System.assertEquals('Test Work Order', workOrders[0].Subject, 'Subject should match');
    }
    
    @isTest
    static void testGetExpenses() {
        WorkOrder testWO = [SELECT Id FROM WorkOrder LIMIT 1];
        
        Test.startTest();
        List<Expense> expenses = MobileReceiptController.getExpenses(testWO.Id);
        Test.stopTest();
        
        System.assertEquals(1, expenses.size(), 'Should return 1 expense');
        System.assertEquals(100.00, expenses[0].Amount, 'Amount should match');
    }
    
    @isTest
    static void testCreateWorkOrder() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        WorkOrder newWO = MobileReceiptController.createWorkOrder(
            testAccount.Id,
            'New Test Work Order',
            'New Description'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, newWO.Id, 'Work Order should be created');
        System.assertEquals('New Test Work Order', newWO.Subject, 'Subject should match');
        System.assertNotEquals(null, newWO.WorkOrderNumber, 'Work Order Number should be generated');
    }
    
    @isTest
    static void testCreateExpense() {
        WorkOrder testWO = [SELECT Id FROM WorkOrder LIMIT 1];
        
        Test.startTest();
        Expense newExpense = MobileReceiptController.createExpense(
            testWO.Id,
            200.00,
            'New Test Expense',
            Date.today()
        );
        Test.stopTest();
        
        System.assertNotEquals(null, newExpense.Id, 'Expense should be created');
        System.assertEquals(200.00, newExpense.Amount, 'Amount should match');
        System.assertNotEquals(null, newExpense.Title, 'Expense Title should be set');
    }
    
    @isTest
    static void testUploadReceiptFile() {
        Expense testExpense = [SELECT Id FROM Expense LIMIT 1];
        
        // Create a simple base64 encoded test image (1x1 pixel PNG)
        String base64Data = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
        
        Test.startTest();
        String contentDocId = MobileReceiptController.uploadReceiptFile(
            testExpense.Id,
            'test-receipt.png',
            base64Data,
            'image/png'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, contentDocId, 'ContentDocument should be created');
        
        // Verify the file was attached
        List<ContentDocumentLink> links = [
            SELECT Id, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocId
            AND LinkedEntityId = :testExpense.Id
        ];
        System.assertEquals(1, links.size(), 'File should be linked to expense');
    }
    
    @isTest
    static void testErrorHandling() {
        // Test with invalid ID
        try {
            MobileReceiptController.getActiveWorkOrders('invalid_id');
            System.assert(false, 'Should have thrown an exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Error'), 'Should throw AuraHandledException');
        }
    }
}