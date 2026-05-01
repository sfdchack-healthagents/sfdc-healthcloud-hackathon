/**
 * EmployeeExpenseLogger
 * 
 * Logs expenses for employees at accounts
 * Creates WorkOrder if needed (only one active per user/account)
 * Then creates Expense record linked to the WorkOrder
 * 
 * @author Agentforce Team
 * @date 2026-04-17
 */
public class EmployeeExpenseLogger {
    
    @InvocableMethod(label='Log Employee Expense' description='Creates work order if needed and logs expense')
    public static List<ExpenseLogResult> logExpense(List<ExpenseLogRequest> requests) {
        List<ExpenseLogResult> results = new List<ExpenseLogResult>();
        
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        
        for (ExpenseLogRequest request : requests) {
            try {
                ExpenseLogResult result = processExpense(request);
                results.add(result);
            } catch (Exception e) {
                ExpenseLogResult errorResult = new ExpenseLogResult();
                errorResult.isSuccess = false;
                errorResult.message = 'Error: ' + e.getMessage();
                results.add(errorResult);
            }
        }
        
        return results;
    }
    
    /**
     * Process single expense request
     * - Find or create active WorkOrder for account/user
     * - Create Expense record linked to WorkOrder
     */
    private static ExpenseLogResult processExpense(ExpenseLogRequest request) {
        System.debug('=== Starting processExpense ===');
        ExpenseLogResult result = new ExpenseLogResult();
        
        // Validate required fields
        if (String.isBlank(request.accountName) && String.isBlank(request.accountId)) {
            throw new IllegalArgumentException('Either Account Name or Account ID is required');
        }
        if (request.expenseAmount == null || request.expenseAmount <= 0) {
            throw new IllegalArgumentException('Valid expense amount is required');
        }
        
        // Get current user (the employee agent)
        String userId = UserInfo.getUserId();
        System.debug('Current User ID: ' + userId);
        
        // Get Account ID - either from direct ID or by name lookup
        String accountId;
        if (String.isNotBlank(request.accountId)) {
            accountId = request.accountId;
            System.debug('Using provided Account ID: ' + accountId);
        } else {
            System.debug('Looking up Account by name: ' + request.accountName);
            // Query Account by name
            List<Account> accounts = [
                SELECT Id 
                FROM Account 
                WHERE Name = :request.accountName 
                LIMIT 1
            ];
            
            if (accounts.isEmpty()) {
                throw new IllegalArgumentException('Account not found: ' + request.accountName);
            }
            
            accountId = accounts[0].Id;
            System.debug('Found Account ID: ' + accountId);
        }
        
        // Find or create active WorkOrder
        System.debug('About to find/create WorkOrder');
        String workOrderId = findOrCreateWorkOrder(accountId, userId);
        
        if (String.isBlank(workOrderId)) {
            throw new IllegalArgumentException('Failed to obtain or create WorkOrder');
        }
        
        System.debug('WorkOrder ID obtained: ' + workOrderId);
        
        // Create Expense record
        System.debug('Creating Expense record');
        Expense newExpense = new Expense();
        newExpense.Title = 'Expense - ' + request.accountName;
        newExpense.Amount = request.expenseAmount;
        newExpense.Description = request.expenseDescription;
        newExpense.TransactionDate = Date.today();
        newExpense.OwnerId = userId;
        newExpense.AccountId = accountId;
        newExpense.WorkOrderId = workOrderId;
        newExpense.ExpenseType = 'Other';
        
        insert newExpense;
        System.debug('Expense created: ' + newExpense.Id);
        
        result.isSuccess = true;
        result.workOrderId = workOrderId;
        
        AgentSFX_RecordOutputWrapper expenseWrapper = new AgentSFX_RecordOutputWrapper();
        expenseWrapper.recId = newExpense.Id;
        result.expense = expenseWrapper;
        
        result.message = 'Expense logged successfully';
        System.debug('=== Completed processExpense successfully ===');
        
        return result;
    }
    
    /**
     * Find active WorkOrder for account/user
     * If none exists, create new one
     */
    private static String findOrCreateWorkOrder(String accountId, String userId) {
        System.debug('Finding or creating WorkOrder for Account: ' + accountId + ' User: ' + userId);
        
        // Query for active WorkOrder
        List<WorkOrder> activeWorkOrders = [
            SELECT Id 
            FROM WorkOrder 
            WHERE AccountId = :accountId 
            AND OwnerId = :userId 
            AND Status NOT IN ('Closed', 'Completed', 'Cancelled')
            LIMIT 1
        ];
        
        // If active WorkOrder exists, return it
        if (!activeWorkOrders.isEmpty()) {
            System.debug('Found existing WorkOrder: ' + activeWorkOrders[0].Id);
            return activeWorkOrders[0].Id;
        }
        
        System.debug('No existing WorkOrder found. Creating new one.');
        
        // Get or create default OperatingHours FIRST
        String operatingHoursId = getOrCreateDefaultOperatingHours();
        System.debug('OperatingHours ID: ' + operatingHoursId);
        
        if (String.isBlank(operatingHoursId)) {
            throw new IllegalArgumentException('Cannot create WorkOrder: No OperatingHours available');
        }
        
        // Get or create default Service Territory (needs OperatingHoursId)
        String serviceTerritoryId = getOrCreateDefaultServiceTerritory(operatingHoursId);
        System.debug('ServiceTerritory ID: ' + serviceTerritoryId);
        
        if (String.isBlank(serviceTerritoryId)) {
            throw new IllegalArgumentException('Cannot create WorkOrder: No Service Territory available');
        }
        
        // Create new WorkOrder
        WorkOrder newWorkOrder = new WorkOrder();
        newWorkOrder.AccountId = accountId;
        newWorkOrder.OwnerId = userId;
        newWorkOrder.Status = 'Open';
        newWorkOrder.StartDate = Date.today();
        newWorkOrder.Description = 'Work Order created for expense logging';
        newWorkOrder.ServiceTerritoryId = serviceTerritoryId;
        
        System.debug('Attempting to insert WorkOrder');
        insert newWorkOrder;
        System.debug('WorkOrder created: ' + newWorkOrder.Id);
        return newWorkOrder.Id;
    }
    
    /**
     * Get existing Service Territory, or create one if none exists
     */
    private static String getOrCreateDefaultServiceTerritory(String operatingHoursId) {
        System.debug('Getting or creating Service Territory');
        
        // Try to find existing Service Territory
        List<ServiceTerritory> territories = [
            SELECT Id 
            FROM ServiceTerritory 
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (!territories.isEmpty()) {
            System.debug('Found existing ServiceTerritory: ' + territories[0].Id);
            return territories[0].Id;
        }
        
        System.debug('No ServiceTerritory found. Creating default one.');
        
        // If none exist, create a default one
        ServiceTerritory defaultTerritory = new ServiceTerritory();
        defaultTerritory.Name = 'Default Service Territory';
        defaultTerritory.IsActive = true;
        defaultTerritory.OperatingHoursId = operatingHoursId;
        
        System.debug('Attempting to insert ServiceTerritory');
        insert defaultTerritory;
        System.debug('ServiceTerritory created: ' + defaultTerritory.Id);
        return defaultTerritory.Id;
    }
    
    /**
     * Get existing OperatingHours, or create one if none exists
     */
    private static String getOrCreateDefaultOperatingHours() {
        System.debug('Getting or creating OperatingHours');
        
        // Try to find existing OperatingHours
        List<OperatingHours> opHoursList = [
            SELECT Id 
            FROM OperatingHours 
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        if (!opHoursList.isEmpty()) {
            System.debug('Found existing OperatingHours: ' + opHoursList[0].Id);
            return opHoursList[0].Id;
        }
        
        System.debug('No OperatingHours found. Creating default one.');
        
        // If none exist, create a default one
        OperatingHours defaultOpHours = new OperatingHours();
        defaultOpHours.Name = 'Default Operating Hours';
        defaultOpHours.TimeZone = 'America/New_York';
        
        System.debug('Attempting to insert OperatingHours');
        insert defaultOpHours;
        System.debug('OperatingHours created: ' + defaultOpHours.Id);
        return defaultOpHours.Id;
    }
    
    // ==================== INPUT CLASS ====================
    
    /**
     * Input variables for expense logging
     */
    public class ExpenseLogRequest {
        @InvocableVariable(label='Account ID' description='ID of the account (if available, takes precedence over Account Name)')
        public String accountId;
        
        @InvocableVariable(label='Account Name' description='Name of the account to log expense for (used if Account ID not provided)')
        public String accountName;
        
        @InvocableVariable(label='Expense Amount' required=true description='Amount of the expense')
        public Decimal expenseAmount;
        
        @InvocableVariable(label='Expense Description' description='Description of the expense')
        public String expenseDescription;
    }
    
    // ==================== OUTPUT CLASS ====================
    
    /**
     * Output variables for expense logging result
     */
    public class ExpenseLogResult {
        @InvocableVariable(label='Success' description='Whether the expense was logged successfully')
        public Boolean isSuccess;
        
        @InvocableVariable(label='WorkOrder ID' description='ID of the work order (created or existing)')
        public String workOrderId;
        
        @InvocableVariable(label='Expense' description='Created expense record wrapper')
        public AgentSFX_RecordOutputWrapper expense;
        
        @InvocableVariable(label='Message' description='Success or error message')
        public String message;
    }
}