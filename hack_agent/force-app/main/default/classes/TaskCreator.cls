public class TaskCreator {
    
    @InvocableMethod(label='Create Task for Contact' description='Creates a task linked to a contact with specified details')
    public static List<TaskCreationResult> createTaskForContact(List<TaskCreationRequest> requests) {
        List<TaskCreationResult> results = new List<TaskCreationResult>();
        List<Task> tasksToCreate = new List<Task>();
        
        for (TaskCreationRequest request : requests) {
            TaskCreationResult result = new TaskCreationResult();
            
            try {
                // Validate required fields
                if (String.isBlank(request.contactId)) {
                    result.isSuccess = false;
                    result.errorMessage = 'Contact ID is required';
                    results.add(result);
                    continue;
                }
                
                if (String.isBlank(request.subject)) {
                    result.isSuccess = false;
                    result.errorMessage = 'Task subject is required';
                    results.add(result);
                    continue;
                }
                
                // Verify contact exists
                List<Contact> contacts = [SELECT Id FROM Contact WHERE Id = :request.contactId LIMIT 1];
                
                if (contacts.isEmpty()) {
                    result.isSuccess = false;
                    result.errorMessage = 'Contact with ID ' + request.contactId + ' not found';
                    results.add(result);
                    continue;
                }
                
                // Create task
                Task newTask = new Task();
                newTask.WhoId = request.contactId;  // Link to Contact
                newTask.Subject = request.subject;
                newTask.Description = request.description;
                newTask.ActivityDate = request.dueDate;
                newTask.Priority = request.priority != null ? request.priority : 'Normal';
                newTask.Status = request.status != null ? request.status : 'Not Started';
                
                if (String.isNotBlank(request.accountId)) {
                    newTask.WhatId = request.accountId;  // Link to Account (optional)
                }
                
                tasksToCreate.add(newTask);
                
                result.isSuccess = true;
                result.errorMessage = '';
                
            } catch (Exception e) {
                result.isSuccess = false;
                result.errorMessage = 'Error: ' + e.getMessage();
                results.add(result);
                continue;
            }
            
            results.add(result);
        }
        
        // Insert all tasks
        if (!tasksToCreate.isEmpty()) {
            try {
                insert tasksToCreate;
                
                // Update results with task IDs
                for (Integer i = 0; i < tasksToCreate.size(); i++) {
                    AgentSFX_RecordOutputWrapper taskWrapper = new AgentSFX_RecordOutputWrapper();
                    taskWrapper.recId = tasksToCreate[i].Id;
                    results[i].taskId = taskWrapper;
                    results[i].isSuccess = true;
                }
            } catch (DmlException e) {
                for (TaskCreationResult result : results) {
                    if (result.isSuccess) {
                        result.isSuccess = false;
                        result.errorMessage = 'Failed to create task: ' + e.getMessage();
                    }
                }
            }
        }
        
        return results;
    }
    
    // Input class for invocable method
    public class TaskCreationRequest {
        @InvocableVariable(label='Contact ID' description='ID of the contact to link the task to' required=true)
        public String contactId;
        
        @InvocableVariable(label='Account ID' description='ID of the account to link the task to (optional)')
        public String accountId;
        
        @InvocableVariable(label='Subject' description='Task subject' required=true)
        public String subject;
        
        @InvocableVariable(label='Description' description='Task description')
        public String description;
        
        @InvocableVariable(label='Due Date' description='Task due date')
        public Date dueDate;
        
        @InvocableVariable(label='Priority' description='Task priority (High, Normal, Low)')
        public String priority;
        
        @InvocableVariable(label='Status' description='Task status (Not Started, In Progress, Completed)')
        public String status;
    }
    
    // Output class for invocable method
    public class TaskCreationResult {
        @InvocableVariable(label='Success' description='Indicates if the task was created successfully')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Task ID' description='ID of the created task')
        public AgentSFX_RecordOutputWrapper taskId;
        
        @InvocableVariable(label='Error Message' description='Error message if creation failed')
        public String errorMessage;
    }
}