/**
 * @description Apex class to create Post Visit Log records from Salesforce Agent
 * Takes visit summary information and creates a Post Visit Log record
 * Author: Devi Pillai
 * Date: 2025-08-07
 */
public with sharing class VisitLogCreator {
    
    /**
     * @description Creates a Post Visit Log record with comprehensive error handling and structured response
     * @param requests Visit log creation request containing visit summary
     * @return List<VisitLogResponse> Structured response with success status, record ID, and message
     */
    @InvocableMethod(label='Create Post Visit Log' description='Creates a Post Visit Log record with visit summary')
    public static List<VisitLogResponse> createVisitLog(List<VisitLogRequest> requests) {
        List<VisitLogResponse> responses = new List<VisitLogResponse>();
        
        for (VisitLogRequest request : requests) {
            VisitLogResponse response = new VisitLogResponse();
            response.recordOutput = new AgentSFX_RecordOutputWrapper();
            
            try {
                // Validate required fields
                if (String.isBlank(request.visitSummary)) {
                    response.recordOutput.recId = null;
                    response.success = false;
                    response.message = 'Error: Visit summary is required';
                    responses.add(response);
                    continue;
                }
                
                // Create and insert Post Visit Log record
                Post_Visit_Log__c newLog = createPostVisitLog(request);
                insert newLog;
                
                response.recordOutput.recId = newLog.Id;
                response.success = true;
                response.message = 'Visit log created successfully';
                
            } catch (DmlException e) {
                response.recordOutput.recId = null;
                response.success = false;
                response.message = 'DML Error: ' + e.getMessage();
            } catch (Exception e) {
                response.recordOutput.recId = null;
                response.success = false;
                response.message = 'Error: ' + e.getMessage();
            }
            
            responses.add(response);
        }
        
        return responses;
    }
    
    /**
     * @description Creates a Post Visit Log record from the request
     * @param request The visit log request containing visit details
     * @return Post_Visit_Log__c The configured Post Visit Log record ready for insertion
     */
    private static Post_Visit_Log__c createPostVisitLog(VisitLogRequest request) {
        if (request == null) {
            throw new IllegalArgumentException('VisitLogRequest cannot be null in createPostVisitLog');
        }
        
        Post_Visit_Log__c newLog = new Post_Visit_Log__c();
        
        if (String.isBlank(request.visitSummary)) {
            throw new IllegalArgumentException('Visit Summary is required');
        }
        
        newLog.Visit_Summary__c = request.visitSummary;
        
        // Set optional fields if provided
        if (String.isNotBlank(request.accountId)) {
            newLog.Clinic__c = request.accountId;
        }
        
        if (String.isNotBlank(request.doctorContactId)) {
            newLog.Doctor__c = request.doctorContactId;
        }
        
        if (String.isNotBlank(request.referralNotes)) {
            newLog.Referral_Notes__c = request.referralNotes;
        }
        
        if (request.expenseAmount != null) {
            newLog.Expense_Amount__c = request.expenseAmount;
        }
        
        if (request.visitDate != null) {
            newLog.Visit_Date__c = request.visitDate;
        } else {
            newLog.Visit_Date__c = Date.today();
        }
        
        newLog.Status__c = 'Processed';
        newLog.Agent_Processed__c = true;
        
        return newLog;
    }
    
    /**
     * @description Wrapper class for visit log creation requests
     */
    public class VisitLogRequest {
        @InvocableVariable(label='Visit Summary' description='Summary of the visit' required=true)
        public String visitSummary;
        
        @InvocableVariable(label='Account ID' description='ID of the clinic/hospital (optional)')
        public String accountId;
        
        @InvocableVariable(label='Doctor Contact ID' description='ID of the doctor/contact (optional)')
        public String doctorContactId;
        
        @InvocableVariable(label='Referral Notes' description='Partnership opportunities or commitments (optional)')
        public String referralNotes;
        
        @InvocableVariable(label='Expense Amount' description='Total expense amount (optional)')
        public Decimal expenseAmount;
        
        @InvocableVariable(label='Visit Date' description='Date of visit. Default is today if not provided (optional)')
        public Date visitDate;
    }
    
    /**
     * @description Helper method to set visit log request fields
     */
    public static void setVisitLogRequestFields(VisitLogRequest req, String summary, String acctId, String doctorId, String notes, Decimal expense, Date vDate) {
        System.debug('DEBUG: setVisitLogRequestFields called with summary=' + summary + ', acctId=' + acctId + ', doctorId=' + doctorId);
        
        if (req == null) {
            throw new IllegalArgumentException('VisitLogRequest cannot be null');
        }
        
        if (String.isBlank(summary)) {
            throw new IllegalArgumentException('Visit summary is required');
        }
        
        System.debug('DEBUG: Setting visitSummary');
        req.visitSummary = summary;
        System.debug('DEBUG: Setting accountId');
        req.accountId = acctId;
        System.debug('DEBUG: Setting doctorContactId');
        req.doctorContactId = doctorId;
        System.debug('DEBUG: Setting referralNotes');
        req.referralNotes = notes;
        System.debug('DEBUG: Setting expenseAmount');
        req.expenseAmount = expense;
        System.debug('DEBUG: Setting visitDate');
        req.visitDate = vDate;
        System.debug('DEBUG: setVisitLogRequestFields completed successfully');
    }
    
    /**
     * @description Wrapper class for visit log creation response with structured data
     */
    public class VisitLogResponse {
        @InvocableVariable(label='Success' description='True when visit log creation succeeds')
        public Boolean success;

        @InvocableVariable(label='Message' description='Visit log creation result message')
        public String message;

        @InvocableVariable(label='Record Output' description='Wrapper containing created visit log record ID')
        public AgentSFX_RecordOutputWrapper recordOutput;
        
        public VisitLogResponse() {
            this.success = false;
            this.message = '';
            this.recordOutput = null;
        }
    }
}