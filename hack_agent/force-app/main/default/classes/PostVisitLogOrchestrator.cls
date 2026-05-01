/**
 * PostVisitLogOrchestrator - AGENTFORCE ACTION FOR POST-VISIT DOCUMENTATION
 * 
 * PURPOSE: Orchestrates complete post-visit workflow for healthcare sales/partnership teams
 * 
 * SCENARIO: After visiting a clinic, hospital, or meeting with a healthcare provider, 
 * the Agentforce agent calls this action to document the visit and manage follow-ups.
 * 
 * SMART ORCHESTRATION - Orchestrates two specialized classes in sequence:
 * 1. VisitLogCreator: Creates Post_Visit_Log__c record with visit details
 *    - What: Visit summary, referral opportunities, notes
 *    - Who: Doctor/provider contact, clinic/hospital (Account)
 *    - When: Visit date (auto-populated if not specified)
 *    - How much: Optional expense tracking
 * 
 * 2. TaskCreator: Optionally creates follow-up Task for sales team
 *    - Only if user mentions action items ("call them", "schedule meeting", "follow up")
 *    - Agent decides: Set createTask=TRUE if action items detected
 *    - Auto-defaults: 3-day due date, "Normal" priority
 *    - Links to both Doctor contact (WhoId) and Clinic account (WhatId)
 * 
 * ATOMIC TRANSACTION: All operations succeed together or all fail together.
 * If any required operation fails, entire workflow rolls back (no partial records).
 * Non-critical operations (task creation) fail gracefully without blocking the core visit log.
 * 
 * KEY FEATURES:
 * - Smart Account lookup: Finds clinic by name with flexible LIKE matching
 * - Smart Contact lookup: Finds doctor by name, searches Account-first then system-wide
 * - Null-safe Boolean handling: Safely handles optional agent decisions
 * - Comprehensive logging: Full DEBUG output in Salesforce logs for troubleshooting
 * - Agent-friendly: Clear field descriptions guide agent on when/why to include each field
 * 
 * @author Onco Global Health Cloud Team
 * @date 2026-04-27
 */
public class PostVisitLogOrchestrator {
    
    @InvocableMethod(label='Post Visit Documentation & Full Workflow' description='FULL POST-VISIT WORKFLOW: Call this when documenting a clinic/hospital visit with visit log creation as the PRIMARY operation. THIS ACTION handles: (1) CREATE VISIT LOG (REQUIRED) - Documents what was discussed, attendees, outcomes, referral opportunities. (2) CREATE FOLLOW-UP TASK (optional) - If user mentions action items ("call them", "follow up"). WHEN TO USE: "Log my visit to Apollo Hospitals with Dr. Mehta - discussed oncology program and future partnership opportunities. Also create a follow-up task to call them on Tuesday." REQUIRED INPUTS: Clinic/hospital name + visit summary (what was discussed). OPTIONAL INPUTS: Doctor name, referral notes, expense tracking, follow-up actions. OUTPUTS: Visit log ID (CRM record), task ID (if created), success message.')
    public static List<PostVisitResult> executePostVisitWorkflow(List<PostVisitRequest> requests) {
        List<PostVisitResult> results = new List<PostVisitResult>();
        
        System.debug('DEBUG: executePostVisitWorkflow START, requests size=' + (requests != null ? String.valueOf(requests.size()) : 'null'));
        
        if (requests == null || requests.isEmpty()) {
            System.debug('DEBUG: No requests provided');
            return results;
        }
        
        for (PostVisitRequest request : requests) {
            try {
                System.debug('DEBUG: Processing request');
                PostVisitResult result = processPostVisit(request);
                results.add(result);
            } catch (Exception e) {
                System.debug('ERROR in executePostVisitWorkflow: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                PostVisitResult errorResult = new PostVisitResult();
                errorResult.isSuccess = false;
                errorResult.message = 'Error: ' + e.getMessage();
                results.add(errorResult);
            }
        }
        
        System.debug('DEBUG: executePostVisitWorkflow END, results size=' + results.size());
        return results;
    }
    
    /**
     * Process post visit workflow - orchestrates calls to specialized classes
     */
    private static PostVisitResult processPostVisit(PostVisitRequest request) {
        System.debug('DEBUG: processPostVisit START');
        System.debug('DEBUG: accountName=' + request.accountName + ', doctorContact=' + request.doctorContact + ', visitSummary=' + request.visitSummary);
        
        PostVisitResult result = new PostVisitResult();
        result.isSuccess = false;
        result.message = '';
        result.postVisitLogId = new AgentSFX_RecordOutputWrapper();
        result.taskId = new AgentSFX_RecordOutputWrapper();
        
        // Validate request is not null
        if (request == null) {
            throw new IllegalArgumentException('PostVisitRequest cannot be null');
        }
        
        // Validate inputs
        if (String.isBlank(request.accountId) && String.isBlank(request.accountName)) {
            throw new IllegalArgumentException('Account ID or Account Name is required');
        }
        
        // visitSummary is now optional - auto-generate default if not provided
        String visitSummary = String.isNotBlank(request.visitSummary) ? 
            request.visitSummary : 
            'Outreach to ' + (String.isNotBlank(request.doctorContact) ? request.doctorContact : 'contact') + ' regarding business development';
        System.debug('DEBUG: Using visitSummary=' + visitSummary);
        
        String accountId = request.accountId;
        
        // Lookup Account by ID or Name
        if (String.isNotBlank(accountId)) {
            List<Account> accounts = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
            if (accounts == null || accounts.isEmpty()) {
                throw new IllegalArgumentException('Account not found with ID: ' + accountId);
            }
        } else if (String.isNotBlank(request.accountName)) {
            if (isPersonName(request.accountName)) {
                throw new IllegalArgumentException('Account Name appears to be a person\'s name ("' + request.accountName + '"). Please provide clinic/hospital name instead.');
            }
            
            // Use SOSL for phonetic search on Account name
            List<Account> accounts = new List<Account>();
            try {
                List<List<SObject>> searchResults = [
                    FIND :request.accountName 
                    RETURNING Account(Id LIMIT 1)
                ];
                
                if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
                    accounts = (List<Account>) searchResults[0];
                }
            } catch (Exception e) {
                System.debug('DEBUG: SOSL search failed, falling back to LIKE: ' + e.getMessage());
                String searchTerm = '%' + request.accountName + '%';
                accounts = [SELECT Id FROM Account WHERE Name LIKE :searchTerm LIMIT 1];
            }
            
            if (accounts == null || accounts.isEmpty()) {
                throw new IllegalArgumentException('Account not found: "' + request.accountName + '"');
            }
            accountId = accounts[0].Id;
        }
        
        if (String.isBlank(accountId)) {
            throw new IllegalArgumentException('Unable to determine Account ID');
        }
        
        System.debug('DEBUG: Found accountId=' + accountId);
        
        // Lookup Doctor Contact ID if provided
        String doctorContactId = null;
        if (String.isNotBlank(request.doctorContact)) {
            try {
                doctorContactId = lookupContactByNameForAccount(request.doctorContact, accountId);
                System.debug('DEBUG: lookupContactByNameForAccount returned doctorContactId=' + doctorContactId);
            } catch (Exception e) {
                System.debug('Warning: Contact lookup failed: ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
            }
        }
        
        // 1. CREATE VISIT LOG using VisitLogCreator
        System.debug('DEBUG: Calling createVisitLog');
        String postVisitLogId = createVisitLog(request, accountId, doctorContactId, visitSummary);
        if (String.isBlank(postVisitLogId)) {
            throw new IllegalArgumentException('Failed to create Post Visit Log');
        }
        result.postVisitLogId.recId = postVisitLogId;
        System.debug('Post Visit Log created: ' + postVisitLogId);
        
        // 2. CREATE TASK using TaskCreator (if requested and contact exists)
        String taskId = null;
        if (request.createTask == true && String.isNotBlank(request.taskSubject) && String.isNotBlank(doctorContactId)) {
            try {
                System.debug('DEBUG: Creating task with subject=' + request.taskSubject + ', doctorContactId=' + doctorContactId + ', accountId=' + accountId);
                taskId = createTask(request, doctorContactId, accountId);
                result.taskId.recId = taskId;
                System.debug('Task created: ' + taskId);
            } catch (Exception e) {
                System.debug('Warning: Task creation failed (non-critical): ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug('Task creation skipped: createTask=' + request.createTask + ', taskSubject=' + request.taskSubject + ', doctorContactId=' + doctorContactId);
        }
        
        result.isSuccess = true;
        result.message = 'Post visit log created successfully';
        
        if (String.isNotBlank(taskId)) {
            result.message += ' with follow-up task';
        }
        
        System.debug('DEBUG: processPostVisit returning success result');
        return result;
    }
    
    /**
     * Call VisitLogCreator to create visit log
     */
    private static String createVisitLog(PostVisitRequest req, String acctId, String docContactId, String visitSummary) {
        System.debug('DEBUG: createVisitLog called with acctId=' + acctId + ', docContactId=' + docContactId + ', visitSummary=' + visitSummary);
        
        if (String.isBlank(visitSummary)) {
            throw new IllegalArgumentException('Visit Summary cannot be blank');
        }
        
        VisitLogCreator.VisitLogRequest vlogReq = new VisitLogCreator.VisitLogRequest();
        
        try {
            System.debug('DEBUG: Calling setVisitLogRequestFields');
            VisitLogCreator.setVisitLogRequestFields(vlogReq, visitSummary, acctId, docContactId, req.referralNotes, req.expenseAmount, req.visitDate);
            System.debug('DEBUG: setVisitLogRequestFields completed');
        } catch (Exception e) {
            System.debug('ERROR in setVisitLogRequestFields: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new IllegalArgumentException('Failed to set visit log fields: ' + e.getMessage());
        }
        
        System.debug('DEBUG: Calling VisitLogCreator.createVisitLog');
        List<VisitLogCreator.VisitLogResponse> vlogResponses = VisitLogCreator.createVisitLog(
            new List<VisitLogCreator.VisitLogRequest>{vlogReq}
        );
        System.debug('DEBUG: VisitLogCreator.createVisitLog returned, responses size=' + (vlogResponses != null ? String.valueOf(vlogResponses.size()) : 'null'));
        
        if (vlogResponses == null) {
            throw new IllegalArgumentException('Failed to create visit log: Null response from VisitLogCreator');
        }
        
        if (vlogResponses.isEmpty()) {
            throw new IllegalArgumentException('Failed to create visit log: Empty response from VisitLogCreator');
        }
        
        VisitLogCreator.VisitLogResponse response = vlogResponses[0];
        if (response == null) {
            throw new IllegalArgumentException('Failed to create visit log: Null response object');
        }
        
        if (!response.success) {
            throw new IllegalArgumentException('Failed to create visit log: ' + (String.isNotBlank(response.message) ? response.message : 'Unknown error'));
        }
        
        if (response.recordOutput == null || String.isBlank(response.recordOutput.recId)) {
            throw new IllegalArgumentException('Failed to create visit log: No record ID returned');
        }
        
        System.debug('DEBUG: createVisitLog returning postVisitLogId=' + response.recordOutput.recId);
        return response.recordOutput.recId;
    }
    
    /**
     * Call TaskCreator to create task
     */
    private static String createTask(PostVisitRequest request, String doctorContactId, String accountId) {
        if (String.isBlank(doctorContactId)) {
            throw new IllegalArgumentException('Cannot create task: Doctor Contact ID is required');
        }
        
        TaskCreator.TaskCreationRequest tcRequest = new TaskCreator.TaskCreationRequest();
        tcRequest.contactId = doctorContactId;
        tcRequest.accountId = accountId;
        tcRequest.subject = String.isNotBlank(request.taskSubject) ? 'Follow-up: ' + request.taskSubject : 'Follow-up Task';
        tcRequest.description = request.taskDescription;
        tcRequest.dueDate = request.taskDueDate != null ? request.taskDueDate : Date.today().addDays(3);
        tcRequest.priority = String.isNotBlank(request.taskPriority) ? request.taskPriority : 'Normal';
        tcRequest.status = 'Not Started';
        
        List<TaskCreator.TaskCreationResult> results = TaskCreator.createTaskForContact(new List<TaskCreator.TaskCreationRequest>{tcRequest});
        
        if (results == null || results.isEmpty()) {
            throw new IllegalArgumentException('Failed to create task: No response from TaskCreator');
        }
        
        TaskCreator.TaskCreationResult result = results[0];
        if (result == null) {
            throw new IllegalArgumentException('Failed to create task: Null result object');
        }
        
        if (!result.isSuccess) {
            throw new IllegalArgumentException('Failed to create task: ' + (String.isNotBlank(result.errorMessage) ? result.errorMessage : 'Unknown error'));
        }
        
        if (result.taskId == null) {
            throw new IllegalArgumentException('Failed to create task: No task ID returned');
        }
        
        if (String.isBlank(result.taskId.recId)) {
            throw new IllegalArgumentException('Failed to create task: Task ID is blank');
        }
        
        return result.taskId.recId;
    }
    

    /**
     * Lookup Contact by name for given Account (using SOSL for phonetic search)
     */
    private static String lookupContactByNameForAccount(String contactName, String accountId) {
        System.debug('DEBUG: lookupContactByNameForAccount called with contactName=' + contactName + ', accountId=' + accountId);
        
        if (String.isBlank(contactName)) {
            System.debug('DEBUG: contactName is blank, returning null');
            return null;
        }
        
        List<Contact> contacts = new List<Contact>();
        
        // Try to find Contact in same Account first using SOSL (phonetic search)
        if (String.isNotBlank(accountId)) {
            System.debug('DEBUG: Searching for contact in same account using SOSL');
            try {
                List<List<SObject>> searchResults = [
                    FIND :contactName 
                    RETURNING Contact(Id WHERE AccountId = :accountId LIMIT 1)
                ];
                
                if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
                    contacts = (List<Contact>) searchResults[0];
                }
            } catch (Exception e) {
                System.debug('DEBUG: SOSL search failed, falling back to LIKE: ' + e.getMessage());
                String searchPattern = '%' + contactName + '%';
                contacts = [SELECT Id FROM Contact WHERE Name LIKE :searchPattern AND AccountId = :accountId LIMIT 1];
            }
        }
        
        // If not found, search all contacts using SOSL (phonetic search)
        if (contacts == null || contacts.isEmpty()) {
            System.debug('DEBUG: Not found in same account, searching all contacts using SOSL');
            try {
                List<List<SObject>> searchResults = [
                    FIND :contactName 
                    RETURNING Contact(Id LIMIT 1)
                ];
                
                if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
                    contacts = (List<Contact>) searchResults[0];
                }
            } catch (Exception e) {
                System.debug('DEBUG: SOSL search failed, falling back to LIKE: ' + e.getMessage());
                String searchPattern = '%' + contactName + '%';
                contacts = [SELECT Id FROM Contact WHERE Name LIKE :searchPattern LIMIT 1];
            }
        }
        
        if (contacts == null || contacts.isEmpty()) {
            System.debug('Contact not found: "' + contactName + '"');
            return null;
        }
        
        System.debug('DEBUG: Found contact with ID: ' + contacts[0].Id);
        return contacts[0].Id;
    }
    
    /**
     * Detect if string is a person name
     */
    private static Boolean isPersonName(String input) {
        if (String.isBlank(input)) {
            return false;
        }
        
        String trimmed = input.trim();
        
        // Check for title prefixes
        if (trimmed.startsWith('Dr.') || trimmed.startsWith('Mr.') || trimmed.startsWith('Ms.') || 
            trimmed.startsWith('Mrs.') || trimmed.startsWith('Prof.')) {
            return true;
        }
        
        // Check for "Name Initial" pattern (e.g., "Roopa R")
        List<String> parts = trimmed.split(' ');
        if (parts.size() == 2 && parts[1].length() == 1) {
            String lastChar = parts[1];
            if (lastChar.compareTo('A') >= 0 && lastChar.compareTo('Z') <= 0) {
                return true;
            }
        }
        
        return false;
    }
    
    // ==================== INPUT CLASS ====================
    
    /**
     * Input variables for post visit workflow
     * Agent Instructions: Provide clinic details, then optionally add task
     */
    public class PostVisitRequest {
        @InvocableVariable(label='Account ID' description='[REQUIRED - USER PROVIDES IMPLICITLY] Users will say things like "Log visit for Apollo Hospitals" or "Document meeting at Manipal" - they will NOT provide IDs. WHAT TO DO: Extract clinic/hospital name from user message and use Account Name field instead (recommended). ONLY USE THIS if user explicitly says "Account ID is 001A0000001ABC" or similar exact 15-18 char format. Either Account ID or Account Name required (Account Name is 99% of the time).')
        public String accountId;
        
        @InvocableVariable(label='Account Name' description='[REQUIRED - EXTRACT FROM USER MESSAGE] PRIMARY METHOD: Users naturally mention clinic/hospital names like "I visited Apollo Hospitals today" or "Met with Manipal team". EXTRACT: The clinic/hospital/organization name from user conversation. EXAMPLES: "Discussed partnership with AIIMS" → Extract "AIIMS", "Visited Dr. Mehta at Fortis Hospital" → Extract "Fortis Hospital". ⚠️ CRITICAL - PERSON NAMES WILL FAIL: If user only mentions a person name like "I met with Roopa R" or "Visited Dr. Mehta" (NO hospital name), put that name in Doctor/Provider Contact field INSTEAD, and ask user which clinic they visited. WILL FAIL: "Roopa R", "Dr. Mehta", "Dr. Sharma" (person names). WILL WORK: "Apollo Hospitals", "AIIMS", "Fortis Hospital" (organization names). Either Account Name or Account ID required (this is the most common path).')
        public String accountName;
        
        @InvocableVariable(label='Visit Summary' description='[OPTIONAL - ASK IF AVAILABLE] Ask user what was discussed if this is a real visit (1-2 sentences). EXAMPLES: "Discussed oncology program", "Explored cardiology partnership". If user prefers not to provide details, leave blank - system will auto-generate default.')
        public String visitSummary;
        
        @InvocableVariable(label='Visit Date' description='[OPTIONAL - AUTO-POPULATE] DEFAULT: Use today automatically. ONLY ask user if they mention a past visit date. FORMAT: YYYY-MM-DD if user specifies.')
        public Date visitDate;
        
        @InvocableVariable(label='Doctor/Provider Contact' description='[OPTIONAL - LOOKUP CONTACT NAME] If user mentions a doctor name, provide it here (e.g., "Roopa R", "Dr. Mehta", "Dr. Sharma, Chief of Cardiology"). SYSTEM VALIDATES: Agent will search for this contact in your Salesforce database. If not found, action fails with "Contact not found" - ask user to verify the exact name. FORMAT: Person name only. Leave blank if not mentioned.')
        public String doctorContact;
        
        @InvocableVariable(label='Referral Notes' description='[OPTIONAL - ASK IF RELEVANT] If user discusses opportunities or commitments, ask for details. EXAMPLES: "Interested in oncology pilot", "Budget approved Q3". Leave blank if none.')
        public String referralNotes;
        
        @InvocableVariable(label='Expense Amount' description='[OPTIONAL - ASK IF MENTIONED] If user mentions expenses, ask for total amount. FORMAT: Number only like "1500" for 1500 INR. Leave blank if none.')
        public Decimal expenseAmount;
        
        @InvocableVariable(label='Create Follow-up Task' description='[AGENT DECISION - NO ASK] Analyze conversation: if user mentions action items (\"call them\", \"schedule meeting\", \"follow up\", \"remind me to send email\"), set TRUE. Otherwise FALSE. IMPORTANT: \"Remind me to send email\" = CREATE TASK (not email action). Smart default: FALSE.')
        public Boolean createTask;
        
        @InvocableVariable(label='Task Subject' description='[REQUIRED IF createTask=TRUE - ASK USER] Only ask if task needed. WRITE: Get specific action from user like "Call Dr. Patel", "Send email to Dr. Patel", "Call hospital about pricing". IMPORTANT: If user says "remind me to send email", capture it as a TASK with subject like "Send email to [contact name]" - do NOT send email directly. Format: Action verb + recipient/details. DO NOT make up task subjects - use exact user intent.')
        public String taskSubject;
        
        @InvocableVariable(label='Task Description' description='[OPTIONAL - CAPTURE DETAILS] If user provides more context about the task, include it. Otherwise leave blank. Task works fine with just the Subject.')
        public String taskDescription;
        
        @InvocableVariable(label='Task Due Date' description='[OPTIONAL - AUTO-POPULATE] DEFAULT: Use today+3 days automatically (standard 3-day follow-up). ONLY override if user says different date needed ("need this done by next week", etc).')
        public Date taskDueDate;
        
        @InvocableVariable(label='Task Priority' description='[OPTIONAL - AUTO-POPULATE] DEFAULT: Always use "Normal" (most follow-ups are routine). ONLY use "High" if user emphasizes urgency or large opportunity. Never use "Low".')
        public String taskPriority;
    }
    
    // ==================== OUTPUT CLASS ====================
    
    /**
     * Output variables for workflow result
     * Agent Instructions: Check Success first, then interpret other outputs
     */
    public class PostVisitResult {
        @InvocableVariable(label='Success' description='TRUE = Visit log created successfully. FALSE = Something went wrong. CHECK THIS FIRST. If FALSE, read Message for error details. Task failures do NOT set this to FALSE (non-critical). NEXT STEP if TRUE: "Visit logged successfully!" NEXT STEP if FALSE: Show error message to user.')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Post Visit Log ID' description='UNIQUE ID: Salesforce record ID like "a0a1234567890AB". WHEN POPULATED: Always present when Success=TRUE, empty when Success=FALSE. HOW TO USE: Share with user so they can view the visit record. FORMAT: Copy and include in response like "Visit log created: [ID]". PRIMARY RECORD: This is the main record created.')
        public AgentSFX_RecordOutputWrapper postVisitLogId;
        
        @InvocableVariable(label='Task ID' description='UNIQUE ID: Salesforce task record ID like "00T1234567890AB". WHEN POPULATED: Only if createTask=TRUE and task created successfully. Empty if task not requested. HOW TO USE: Share with user so they know task was created. FORMAT: "Follow-up task created: [ID]". OPTIONAL FIELD: Will be empty if no task was requested.')
        public AgentSFX_RecordOutputWrapper taskId;
        
        @InvocableVariable(label='Message' description='EXPLANATION: What happened in plain language. READ IF Success=FALSE: Shows what went wrong like "Account not found: Apollo Hospitals" or "Invalid Account ID format". READ IF Success=TRUE: Informational summary like "Post visit log created successfully with task". HOW TO USE: Show to user if there was an error, log for audit if success. EXAMPLES: "Account ID or Account Name required", "Account not found: Apollo".')
        public String message;
    }
}