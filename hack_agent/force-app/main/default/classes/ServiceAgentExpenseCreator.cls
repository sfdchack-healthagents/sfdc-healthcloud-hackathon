public class ServiceAgentExpenseCreator {
    
    @InvocableMethod(label='Create Expense from Service Agent' description='Creates an expense record from service agent input')
    public static List<ExpenseCreationResult> createExpense(List<ExpenseCreationRequest> requests) {
        List<ExpenseCreationResult> results = new List<ExpenseCreationResult>();
        List<Expense> expensesToCreate = new List<Expense>();
        Map<Integer, ExpenseCreationRequest> requestMap = new Map<Integer, ExpenseCreationRequest>();
        
        for (Integer i = 0; i < requests.size(); i++) {
            ExpenseCreationRequest request = requests[i];
            ExpenseCreationResult result = new ExpenseCreationResult();
            
            try {
                // Validate required fields
                if (String.isBlank(request.employeeId) && String.isBlank(request.userId)) {
                    result.isSuccess = false;
                    result.errorMessage = 'Either Employee Phone or User ID is required';
                    results.add(result);
                    continue;
                }
                
                if (String.isBlank(request.title)) {
                    result.isSuccess = false;
                    result.errorMessage = 'Expense title is required';
                    results.add(result);
                    continue;
                }
                
                if (request.amount == null || request.amount <= 0) {
                    result.isSuccess = false;
                    result.errorMessage = 'Valid amount is required';
                    results.add(result);
                    continue;
                }
                
                // Get employee ID - either from direct ID or by phone lookup
                String actualEmployeeId;
                if (String.isNotBlank(request.userId)) {
                    // If User ID is provided, use it directly
                    actualEmployeeId = request.userId;
                } else {
                    // Query User by phone number
                    List<User> users = [SELECT Id FROM User WHERE Phone = :request.employeeId LIMIT 1];
                    
                    if (users.isEmpty()) {
                        result.isSuccess = false;
                        result.errorMessage = 'Employee with phone number ' + request.employeeId + ' not found';
                        results.add(result);
                        continue;
                    }
                    
                    actualEmployeeId = users[0].Id;
                }
                
                // Create expense record
                Expense newExpense = new Expense();
                newExpense.Title = request.title;
                newExpense.Amount = request.amount;
                newExpense.ExpenseType = request.category;
                newExpense.Description = request.description;
                newExpense.TransactionDate = request.expenseDate;
                newExpense.OwnerId = actualEmployeeId;  // Assign to employee
                
                if (String.isNotBlank(request.accountId)) {
                    newExpense.AccountId = request.accountId;
                }
                
                expensesToCreate.add(newExpense);
                requestMap.put(expensesToCreate.size() - 1, request);
                
                // Mark for processing
                result.isSuccess = true;
                
            } catch (Exception e) {
                ExpenseCreationResult errorResult = new ExpenseCreationResult();
                errorResult.isSuccess = false;
                errorResult.errorMessage = 'Validation error: ' + e.getMessage();
                results.add(errorResult);
                continue;
            }
            
            results.add(result);
        }
        
        // Insert all expenses in single DML
        if (!expensesToCreate.isEmpty()) {
            try {
                insert expensesToCreate;
                
                // Update results with created IDs
                Integer resultIndex = 0;
                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess && resultIndex < expensesToCreate.size()) {
                        results[i].expenseId = expensesToCreate[resultIndex].Id;
                        resultIndex++;
                    }
                }
            } catch (DmlException e) {
                // Handle bulk insert failure
                for (ExpenseCreationResult result : results) {
                    if (result.isSuccess) {
                        result.isSuccess = false;
                        result.errorMessage = 'Failed to create expense: ' + e.getDmlMessage(0);
                    }
                }
            }
        }
        
        return results;
    }
    
    // Input class for invocable method
    public class ExpenseCreationRequest {
        @InvocableVariable(label='User ID' description='Salesforce User ID (if available, takes precedence over phone)')
        public String userId;
        
        @InvocableVariable(label='Employee Phone' description='Phone number of the employee to create expense for (used if User ID not provided)')
        public String employeeId;
        
        @InvocableVariable(label='Account ID' description='Related account ID (optional)')
        public String accountId;
        
        @InvocableVariable(label='Title' description='Expense title/subject' required=true)
        public String title;
        
        @InvocableVariable(label='Description' description='Detailed description of the expense')
        public String description;
        
        @InvocableVariable(label='Amount' description='Expense amount' required=true)
        public Decimal amount;
        
        @InvocableVariable(label='Category' description='Expense category/type')
        public String category;
        
        @InvocableVariable(label='Expense Date' description='Date of the expense')
        public Date expenseDate;
    }
    
    // Output class for invocable method
    public class ExpenseCreationResult {
        @InvocableVariable(label='Success' description='Whether the expense was created successfully')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Expense ID' description='ID of the created expense record')
        public String expenseId;
        
        @InvocableVariable(label='Error Message' description='Error details if creation failed')
        public String errorMessage;
    }
}