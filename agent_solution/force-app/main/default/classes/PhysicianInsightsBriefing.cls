/**
 * @description Invocable Apex action for Prompt Builder
 * Retrieves comprehensive physician and practice intelligence 
 */
public with sharing class PhysicianInsightsBriefing {

    public class Request {
        @InvocableVariable(required=true label='Healthcare Provider ID')
        public Id healthcareProviderId;
    }

    public class Response {
        @InvocableVariable(label='Physician Profile')
        public PhysicianProfile physicianProfile;
        
        @InvocableVariable(label='Related Contacts')
        public List<ContactInfo> relatedContacts;
        
        @InvocableVariable(label='Account Details')
        public List<AccountInfo> accountDetails;
        
        @InvocableVariable(label='Recent Activities')
        public List<ActivityRecord> recentActivities;
        
        @InvocableVariable(label='Visit History')
        public List<VisitLogInfo> visitHistory;
    }

    @InvocableMethod(label='Get Physician Insights' 
                     description='Retrieves comprehensive physician data for pre-visit briefing')
    public static List<Response> getPhysicianInsights(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res = buildPhysicianBrief(req.healthcareProviderId);
            responses.add(res);
        }

        return responses;
    }

    private static Response buildPhysicianBrief(Id providerId) {
        Response result = new Response();
        
        try {
            // 1. Get HealthcareProvider record
            List<HealthcareProvider> providers = [
                SELECT Id, Name, ProviderType, ProviderClass, 
                       AccountId, Account.Name, ReferredByContactId, Status
                FROM HealthcareProvider 
                WHERE Id = :providerId 
                LIMIT 1
            ];
            
            if (providers.isEmpty()) {
                return result;
            }
            
            HealthcareProvider provider = providers[0];
            
            // Build physician profile
            result.physicianProfile = new PhysicianProfile();
            result.physicianProfile.name = provider.Name;
            result.physicianProfile.specialty = provider.ProviderType;
            result.physicianProfile.title = provider.ProviderClass;
            result.physicianProfile.credentials = provider.ProviderType;
            result.physicianProfile.status = provider.Status;
            result.physicianProfile.isActive = provider.Status == 'Active' ? true : false;
            
            // 2. Get associated Contact records
            List<Contact> contacts = new List<Contact>();
            
            if (provider.ReferredByContactId != null) {
                contacts = [
                    SELECT Id, Name, AccountId, Account.Name, Phone, Email, 
                           Account.BillingCity, Account.BillingState, Account.Phone
                    FROM Contact 
                    WHERE Id = :provider.ReferredByContactId
                    LIMIT 1
                ];
            }
            
            // Initialize variable collections for use throughout method
            Set<Id> contactIds = new Set<Id>();
            Set<Id> accountIds = new Set<Id>();
            
            if (!contacts.isEmpty()) {
                result.relatedContacts = new List<ContactInfo>();
                
                for (Contact contact : contacts) {
                    ContactInfo contactInfo = new ContactInfo();
                    contactInfo.contactId = contact.Id;
                    contactInfo.contactName = contact.Name;
                    contactInfo.accountId = contact.AccountId;
                    contactInfo.accountName = contact.Account.Name;
                    result.relatedContacts.add(contactInfo);
                    
                    contactIds.add(contact.Id);
                    if (String.isNotBlank(contact.AccountId)) {
                        accountIds.add(contact.AccountId);
                    }
                }
                
                // 3. Get Account details
                System.debug('DEBUG: Fetching Account details');
                if (!accountIds.isEmpty()) {
                    List<Account> accounts = [
                        SELECT Id, Name, BillingStreet, BillingCity, BillingState, BillingPostalCode, 
                               Phone, Industry, Website, AnnualRevenue, NumberOfEmployees
                        FROM Account 
                        WHERE Id IN :accountIds
                    ];
                    
                    result.accountDetails = new List<AccountInfo>();
                    for (Account account : accounts) {
                        AccountInfo accInfo = new AccountInfo();
                        accInfo.accountId = account.Id;
                        accInfo.accountName = account.Name;
                        accInfo.city = account.BillingCity;
                        accInfo.state = account.BillingState;
                        accInfo.phone = account.Phone;
                        accInfo.industry = account.Industry;
                        accInfo.website = account.Website;
                        result.accountDetails.add(accInfo);
                    }
                }
            }
            
            // 4. Get Activities (Tasks and Events) related to contacts
            System.debug('DEBUG: Fetching Activities (Tasks and Events)');
            if (!contactIds.isEmpty()) {
                // Get Tasks
                List<Task> tasks = [
                    SELECT Id, Subject, ActivityDate, Status, Priority, Description, WhoId, CreatedDate
                    FROM Task 
                    WHERE WhoId IN :contactIds
                    ORDER BY CreatedDate DESC
                    LIMIT 100
                ];
                
                // Get Events
                List<Event> events = [
                    SELECT Id, Subject, ActivityDateTime, EventSubtype, Description, WhoId, CreatedDate
                    FROM Event 
                    WHERE WhoId IN :contactIds
                    ORDER BY CreatedDate DESC
                    LIMIT 100
                ];
                
                result.recentActivities = new List<ActivityRecord>();
                
                for (Task task : tasks) {
                    ActivityRecord activity = new ActivityRecord();
                    activity.activityId = task.Id;
                    activity.activityType = 'Task';
                    activity.subject = task.Subject;
                    activity.status = task.Status;
                    activity.priority = task.Priority;
                    activity.description = task.Description;
                    activity.activityDate = String.valueOf(task.ActivityDate);
                    result.recentActivities.add(activity);
                }
                
                for (Event event : events) {
                    ActivityRecord activity = new ActivityRecord();
                    activity.activityId = event.Id;
                    activity.activityType = 'Event';
                    activity.subject = event.Subject;
                    activity.status = event.EventSubtype;
                    activity.description = event.Description;
                    activity.activityDate = String.valueOf(event.ActivityDateTime);
                    result.recentActivities.add(activity);
                }
                System.debug('DEBUG: Found ' + result.recentActivities.size() + ' activities');
                
                // 5. Get Post Visit Logs
                System.debug('DEBUG: Fetching Post Visit Logs');
                List<Post_Visit_Log__c> visitLogs = [
                    SELECT Id, Name, Visit_Date__c, Doctor__c, Doctor__r.Name, 
                           Clinic__c, Clinic__r.Name, Visit_Summary__c, Referral_Notes__c, 
                           CreatedDate, LastModifiedDate
                    FROM Post_Visit_Log__c 
                    WHERE Doctor__c IN :contactIds
                    ORDER BY Visit_Date__c DESC
                    LIMIT 50
                ];
                
                result.visitHistory = new List<VisitLogInfo>();
                for (Post_Visit_Log__c log : visitLogs) {
                    VisitLogInfo visitInfo = new VisitLogInfo();
                    visitInfo.visitLogId = log.Id;
                    visitInfo.visitDate = String.valueOf(log.Visit_Date__c);
                    visitInfo.visitSummary = log.Visit_Summary__c;
                    visitInfo.referralNotes = log.Referral_Notes__c;
                    visitInfo.accountName = log.Clinic__r.Name;
                    result.visitHistory.add(visitInfo);
                }
                
                System.debug('DEBUG: Found ' + result.visitHistory.size() + ' visit logs');
            }
        } catch (Exception e) {
            System.debug('Error in buildPhysicianBrief: ' + e.getMessage());
        }
        
        return result;
    }
    
    
    // ==================== INNER CLASSES ====================
    
    public class PhysicianProfile {
        @InvocableVariable(label='Name')
        public String name;
        
        @InvocableVariable(label='Specialty')
        public String specialty;
        
        @InvocableVariable(label='Title')
        public String title;
        
        @InvocableVariable(label='Credentials')
        public String credentials;
        
        @InvocableVariable(label='Status')
        public String status;
        
        @InvocableVariable(label='Is Active')
        public Boolean isActive;
    }
    
    public class ContactInfo {
        @InvocableVariable(label='Contact ID')
        public String contactId;
        
        @InvocableVariable(label='Contact Name')
        public String contactName;
        
        @InvocableVariable(label='Account ID')
        public String accountId;
        
        @InvocableVariable(label='Account Name')
        public String accountName;
    }
    
    public class AccountInfo {
        @InvocableVariable(label='Account ID')
        public String accountId;
        
        @InvocableVariable(label='Account Name')
        public String accountName;
        
        @InvocableVariable(label='City')
        public String city;
        
        @InvocableVariable(label='State')
        public String state;
        
        @InvocableVariable(label='Phone')
        public String phone;
        
        @InvocableVariable(label='Industry')
        public String industry;
        
        @InvocableVariable(label='Website')
        public String website;
    }
    
    public class ActivityRecord {
        @InvocableVariable(label='Activity ID')
        public String activityId;
        
        @InvocableVariable(label='Activity Type')
        public String activityType;
        
        @InvocableVariable(label='Subject')
        public String subject;
        
        @InvocableVariable(label='Status')
        public String status;
        
        @InvocableVariable(label='Priority')
        public String priority;
        
        @InvocableVariable(label='Description')
        public String description;
        
        @InvocableVariable(label='Activity Date')
        public String activityDate;
    }
    
    public class VisitLogInfo {
        @InvocableVariable(label='Visit Log ID')
        public String visitLogId;
        
        @InvocableVariable(label='Visit Date')
        public String visitDate;
        
        @InvocableVariable(label='Visit Summary')
        public String visitSummary;
        
        @InvocableVariable(label='Referral Notes')
        public String referralNotes;
        
        @InvocableVariable(label='Account Name')
        public String accountName;
    }
}