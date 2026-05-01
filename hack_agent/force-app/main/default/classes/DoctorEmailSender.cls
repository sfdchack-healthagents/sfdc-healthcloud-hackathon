/**
 * DoctorEmailSender
 * 
 * Sends emails to contacts with healthcare brochure attachments
 * Integrates with Agentforce agent for automated doctor outreach
 * 
 * User provides:
 * - Brochure name (query ContentDocument library)
 * - Contact name (query Contact records)
 * Class handles finding both and sending email with attachment
 * 
 * @author Onco Global Health Cloud Team
 * @date 2026-04-10
 */
public with sharing class DoctorEmailSender {

    /**
     * Sends email to contact with brochure attachment
     * Invocable method for Agentforce agent
     * 
     * User provides either contact ID or contact name and brochure name
     * If contact ID is provided, it takes precedence over contact name
     * 
     * @param requests List of SendEmailRequest containing contact ID/name and brochure name
     * @return List of email send results
     */
    @InvocableMethod(
        label='Send Email to Doctor (Email-Only)' 
        description='EMAIL-ONLY ACTION: Use this when user asks to JUST send an email/brochure to a doctor WITHOUT documenting a visit. DOES NOT create visit logs or tasks. WHEN TO USE: "Send the Agentforce brochure to Dr. Mehta at Apollo Hospitals", "Email the healthcare resources to Roopa R", "Send them our cancer screening material". USER PROVIDES: Doctor name or ID, brochure document name. SYSTEM PROVIDES: Auto-generated professional email subject + personalized greeting with contact info. OUTPUTS: Email send status and delivery confirmation.'
    )
    public static List<EmailSendResult> sendDoctorEmail(List<SendEmailRequest> requests) {
        List<EmailSendResult> results = new List<EmailSendResult>();
        
        if (requests == null || requests.isEmpty()) {
            return results;
        }
        
        for (SendEmailRequest request : requests) {
            try {
                EmailSendResult result = sendEmail(request);
                results.add(result);
            } catch (Exception e) {
                EmailSendResult errorResult = new EmailSendResult();
                errorResult.success = false;
                errorResult.message = 'Error: ' + e.getMessage();
                errorResult.contactName = request.contactName;
                results.add(errorResult);
            }
        }
        
        return results;
    }

    /**
     * Internal method to send single email
     */
    private static EmailSendResult sendEmail(SendEmailRequest request) {
        EmailSendResult result = new EmailSendResult();
        result.contactName = request.contactName;
        result.brochureName = request.brochureName;
        
        // Validate required fields
        if (String.isBlank(request.brochureName)) {
            throw new IllegalArgumentException('Brochure name is required');
        }
        
        // Get Contact - either by ID (preferred) or by name
        Contact doctor;
        if (String.isNotBlank(request.contactId)) {
            doctor = findContactById(request.contactId);
            if (doctor == null) {
                throw new IllegalArgumentException('Contact not found with ID: ' + request.contactId);
            }
        } else if (String.isNotBlank(request.contactName)) {
            doctor = findContactByName(request.contactName);
            if (doctor == null) {
                throw new IllegalArgumentException('Contact not found: ' + request.contactName);
            }
        } else {
            throw new IllegalArgumentException('Either Contact ID or Contact Name is required');
        }
        
        if (String.isBlank(doctor.Email)) {
            throw new IllegalArgumentException('Contact has no email address: ' + request.contactName);
        }
        
        result.contactEmail = doctor.Email;
        
        // Query ContentDocument by name
        ContentDocument brochureDoc = findContentDocumentByName(request.brochureName);
        if (brochureDoc == null) {
            throw new IllegalArgumentException('Brochure document not found: ' + request.brochureName);
        }
        
        // Get latest version of document
        ContentVersion cv = [
            SELECT VersionData 
            FROM ContentVersion 
            WHERE ContentDocumentId = :brochureDoc.Id 
            AND IsLatest = true 
            LIMIT 1
        ];
        
        if (cv == null) {
            throw new IllegalArgumentException('Could not retrieve brochure content version for: ' + request.brochureName);
        }
        
        // Create email message
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        
        // Set recipient
        email.setToAddresses(new String[] { doctor.Email });
        
        // Set subject
        String subject = String.isBlank(request.emailSubject) ? 
            'Healthcare Resources from Onco Global' : request.emailSubject;
        email.setSubject(subject);
        
        // Set body
        String body = String.isBlank(request.emailBody) ? 
            getDefaultEmailBody(doctor.FirstName) : request.emailBody;
        email.setPlainTextBody(body);
        
        // Attach brochure
        Messaging.EmailFileAttachment attach = new Messaging.EmailFileAttachment();
        attach.setFileName(brochureDoc.Title + '.pdf');
        attach.setBody(cv.VersionData);
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attach });
        
        // Send email
        Messaging.SendEmailResult[] sendResult = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        
        if (sendResult[0].isSuccess()) {
            result.success = true;
            result.message = 'Email sent successfully to ' + doctor.Email;
        } else {
            result.success = false;
            result.message = 'Email send failed: ' + sendResult[0].getErrors()[0].getMessage();
        }
        
        return result;
    }

    /**
     * Finds Contact by ID using SOQL
     * 
     * @param contactId ID of contact to retrieve
     * @return Contact record or null if not found
     */
    private static Contact findContactById(String contactId) {
        try {
            List<Contact> contacts = [
                SELECT Id, Email, FirstName, LastName 
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
            
            return contacts.isEmpty() ? null : contacts[0];
        } catch (QueryException e) {
            System.debug('Error finding contact by ID: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Finds Contact by name using SOQL
     * Searches FirstName + LastName combination
     * 
     * @param contactName Name to search (e.g., "John Smith" or "Dr. Smith")
     * @return Contact record or null if not found
     */
    private static Contact findContactByName(String contactName) {
        try {
            // Try exact match first
            List<Contact> contacts = [
                SELECT Id, Email, FirstName, LastName 
                FROM Contact 
                WHERE Name = :contactName 
                LIMIT 1
            ];
            
            if (!contacts.isEmpty()) {
                return contacts[0];
            }
            
            // Try partial match (contains)
            String namePattern = '%' + contactName + '%';
            contacts = [
                SELECT Id, Email, FirstName, LastName 
                FROM Contact 
                WHERE Name LIKE :namePattern 
                LIMIT 1
            ];
            
            if (!contacts.isEmpty()) {
                return contacts[0];
            }
            
            return null;
        } catch (QueryException e) {
            System.debug('Error finding contact: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Finds ContentDocument by name using SOQL
     * Searches Title field of ContentDocument
     * 
     * @param documentName Name of brochure document
     * @return ContentDocument record or null if not found
     */
    private static ContentDocument findContentDocumentByName(String documentName) {
        try {
            // Try exact match first
            List<ContentDocument> docs = [
                SELECT Id, Title 
                FROM ContentDocument 
                WHERE Title = :documentName 
                LIMIT 1
            ];
            
            if (!docs.isEmpty()) {
                return docs[0];
            }
            
            // Try partial match (contains)
            String docPattern = '%' + documentName + '%';
            docs = [
                SELECT Id, Title 
                FROM ContentDocument 
                WHERE Title LIKE :docPattern 
                LIMIT 1
            ];
            
            if (!docs.isEmpty()) {
                return docs[0];
            }
            
            return null;
        } catch (QueryException e) {
            System.debug('Error finding ContentDocument: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Default email body template
     */
    private static String getDefaultEmailBody(String firstName) {
        String name = String.isBlank(firstName) ? 'Dr.' : firstName;
        
        return 'Dear ' + name + ',\n\n' +
            'We hope this email finds you well.\n\n' +
            'Please find attached our healthcare resources and treatment information that may be valuable for your practice.\n\n' +
            'We are committed to supporting physicians like yourself in providing the best care to patients. ' +
            'If you have any questions or would like to discuss how we can collaborate, please do not hesitate to reach out.\n\n' +
            'Best regards,\n' +
            'Onco Global Healthcare Team\n' +
            'Phone: (555) 123-4567\n' +
            'Email: partnerships@oncoglobal.com';
    }

    // ==================== INPUT CLASS ====================

    /**
     * Input variables for sending doctor emails
     */
    public class SendEmailRequest {
        @InvocableVariable(label='Contact ID' description='ID of contact to email (takes precedence over Contact Name)')
        public String contactId;

        @InvocableVariable(label='Contact Name' description='Name of doctor/contact to email (e.g., Dr. Smith, John Doe) - used if Contact ID not provided')
        public String contactName;

        @InvocableVariable(label='Brochure Name' required=true description='Name of brochure document in library (e.g., Treatment Guide, Clinical Trial Info)')
        public String brochureName;

        @InvocableVariable(label='Email Subject' description='Custom email subject line')
        public String emailSubject;

        @InvocableVariable(label='Email Body' description='Custom email body text')
        public String emailBody;
    }

    // ==================== OUTPUT CLASS ====================

    /**
     * Output variables for email send result
     */
    public class EmailSendResult {
        @InvocableVariable(label='Contact Name' description='Contact name provided')
        public String contactName;

        @InvocableVariable(label='Contact Email' description='Email address found for contact')
        public String contactEmail;

        @InvocableVariable(label='Brochure Name' description='Brochure name provided')
        public String brochureName;

        @InvocableVariable(label='Success' description='Whether email was sent successfully')
        public Boolean success;

        @InvocableVariable(label='Message' description='Success/error message')
        public String message;
    }
}