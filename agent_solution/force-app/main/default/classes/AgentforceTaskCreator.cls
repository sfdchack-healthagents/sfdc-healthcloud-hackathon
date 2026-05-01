/**
 * AgentforceTaskCreator
 * 
 * Provides invocable actions for Agentforce Post-Visit Log Agent
 * Handles Task record creation with automatic Contact/Person Account lookup by name
 * 
 * @author Onco Global Health Cloud Team
 * @date 2026-04-10
 */
public with sharing class AgentforceTaskCreator {

    /**
     * Creates a single Task record
     * Invocable method for Agentforce agent integration
     * Queries Contact or Person Account by name to link task
     * 
     * @param requests List of CreateTaskRequest containing task details
     */
    @InvocableMethod(label='Create Task' description='Creates a Task record from Agentforce agent, queries Contact/Person Account by name')
    public static List<CreateTaskResult> createTask(List<CreateTaskRequest> requests) {
        List<CreateTaskResult> results = new List<CreateTaskResult>();
        
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        
        List<Task> tasksToInsert = new List<Task>();
        
        for (CreateTaskRequest request : requests) {
            try {
                // Validate required fields
                if (String.isBlank(request.subject)) {
                    throw new IllegalArgumentException('Subject is required');
                }
                
                Task newTask = new Task();
                newTask.Subject = request.subject;
                newTask.Description = request.description;
                newTask.Priority = request.priority;
                newTask.Status = request.status;
                newTask.ActivityDate = request.dueDate;
                
                // Query and link to Contact or Person Account by name
                if (String.isNotBlank(request.relatedToName)) {
                    String whoId = null;
                    
                    if (request.relatedToType == 'Contact') {
                        // Query Contact by name
                        whoId = findContactIdByName(request.relatedToName);
                        if (whoId == null) {
                            throw new IllegalArgumentException('Contact not found: ' + request.relatedToName);
                        }
                    } else if (request.relatedToType == 'PersonAccount') {
                        // Query Person Account by name
                        whoId = findPersonAccountIdByName(request.relatedToName);
                        if (whoId == null) {
                            throw new IllegalArgumentException('Person Account not found: ' + request.relatedToName);
                        }
                    }
                    
                    if (whoId != null) {
                        newTask.WhoId = whoId;
                    }
                }
                

                
                tasksToInsert.add(newTask);
            } catch (Exception e) {
                CreateTaskResult errorResult = new CreateTaskResult();
                errorResult.success = false;
                errorResult.message = 'Error: ' + e.getMessage();
                results.add(errorResult);
            }
        }
        
        // Insert all tasks
        if (!tasksToInsert.isEmpty()) {
            try {
                insert tasksToInsert;
                
                for (Task createdTask : tasksToInsert) {
                    CreateTaskResult result = new CreateTaskResult();
                    result.taskId = createdTask.Id;
                    result.success = true;
                    result.message = 'Task created successfully';
                    results.add(result);
                }
            } catch (Exception e) {
                CreateTaskResult errorResult = new CreateTaskResult();
                errorResult.success = false;
                errorResult.message = 'Insert failed: ' + e.getMessage();
                results.add(errorResult);
            }
        }
        
        return results;
    }

    /**
     * Finds Contact ID by name using SOQL
     * Tries exact match first, then partial match
     * 
     * @param contactName Name to search
     * @return Contact ID or null if not found
     */
    private static String findContactIdByName(String contactName) {
        try {
            // Try exact match
            List<Contact> contacts = [
                SELECT Id 
                FROM Contact 
                WHERE Name = :contactName 
                LIMIT 1
            ];
            
            if (!contacts.isEmpty()) {
                return contacts[0].Id;
            }
            
            // Try partial match
            String namePattern = '%' + contactName + '%';
            contacts = [
                SELECT Id 
                FROM Contact 
                WHERE Name LIKE :namePattern 
                LIMIT 1
            ];
            
            if (!contacts.isEmpty()) {
                return contacts[0].Id;
            }
            
            return null;
        } catch (QueryException e) {
            System.debug('Error finding contact: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Finds Person Account ID by name using SOQL
     * Queries Account obj where IsPersonAccount = true
     * Tries exact match first, then partial match
     * 
     * @param personAccountName Name to search
     * @return Person Account ID or null if not found
     */
    private static String findPersonAccountIdByName(String personAccountName) {
        try {
            // Try exact match
            List<Account> accounts = [
                SELECT Id 
                FROM Account 
                WHERE IsPersonAccount = true 
                AND Name = :personAccountName 
                LIMIT 1
            ];
            
            if (!accounts.isEmpty()) {
                return accounts[0].Id;
            }
            
            // Try partial match
            String namePattern = '%' + personAccountName + '%';
            accounts = [
                SELECT Id 
                FROM Account 
                WHERE IsPersonAccount = true 
                AND Name LIKE :namePattern 
                LIMIT 1
            ];
            
            if (!accounts.isEmpty()) {
                return accounts[0].Id;
            }
            
            return null;
        } catch (QueryException e) {
            System.debug('Error finding person account: ' + e.getMessage());
            return null;
        }
    }

    // ==================== INPUT CLASS ====================

    /**
     * Input variables for Task creation
     */
    public class CreateTaskRequest {
        @InvocableVariable(label='Subject' required=true description='Task subject line')
        public String subject;

        @InvocableVariable(label='Description' description='Task description/notes')
        public String description;

        @InvocableVariable(label='Priority' description='High, Normal, or Low')
        public String priority;

        @InvocableVariable(label='Status' description='Task status (e.g., Open, In Progress)')
        public String status;

        @InvocableVariable(label='Due Date' description='Task due date')
        public Date dueDate;

        @InvocableVariable(label='Contact/Account' description='Type of record to link task (Contact or Account)')
        public String relatedToType;

        @InvocableVariable(label='Related To Name' description='Name of Contact or Person Account to link task')
        public String relatedToName;
    }

    // ==================== OUTPUT CLASS ====================

    /**
     * Output variables for Task creation result
     */
    public class CreateTaskResult {
        @InvocableVariable(label='Task ID' description='ID of created Task record')
        public String taskId;

        @InvocableVariable(label='Success' description='Whether task was created successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='Result message')
        public String message;
    }
}