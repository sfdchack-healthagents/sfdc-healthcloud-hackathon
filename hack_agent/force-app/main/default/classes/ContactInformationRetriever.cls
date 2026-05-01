public class ContactInformationRetriever {
    
    @InvocableMethod(label='Get Contact Information' description='Retrieves contact with name, account name, and email for the user to decide for which contact he wants to create a succive task/event on')
    public static List<ContactResult> getContactInformation(List<ContactRequest> requests) {
        List<ContactResult> results = new List<ContactResult>();
        
        for (ContactRequest request : requests) {
            ContactResult result = new ContactResult();
            
            try {
                // Build the query condition
                String whereClause = '';
                
                if (String.isNotBlank(request.contactId)) {
                    // Search by Contact ID
                    whereClause = 'Id = \'' + String.escapeSingleQuotes(request.contactId) + '\'';
                } else if (String.isNotBlank(request.contactName)) {
                    // Search by Contact Name
                    whereClause = 'Name LIKE \'%' + String.escapeSingleQuotes(request.contactName) + '%\'';
                } else {
                    result.isSuccess = false;
                    result.errorMessage = 'Please provide either Contact ID or Contact Name';
                    results.add(result);
                    continue;
                }
                
                // Query contact with account information
                String query = 'SELECT Id, FirstName, LastName, Email, Account.Name FROM Contact WHERE ' + whereClause + ' LIMIT 1';
                List<Contact> contacts = Database.query(query);
                
                if (contacts.isEmpty()) {
                    result.isSuccess = false;
                    result.errorMessage = 'Contact not found';
                } else {
                    Contact contact = contacts[0];
                    result.isSuccess = true;
                    result.contactId = contact.Id;
                    result.contactName = contact.FirstName + ' ' + contact.LastName;
                    result.email = contact.Email;
                    result.accountName = contact.Account != null ? contact.Account.Name : '';
                    result.errorMessage = '';
                }
                
            } catch (Exception e) {
                result.isSuccess = false;
                result.errorMessage = 'Error: ' + e.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    // Input class for invocable method
    public class ContactRequest {
        @InvocableVariable(label='Contact ID' description='ID of the contact to search')
        public String contactId;
        
        @InvocableVariable(label='Contact Name' description='Name of the contact to search (supports partial match)')
        public String contactName;
    }
    
    // Output class for invocable method
    public class ContactResult {
        @InvocableVariable(label='Success' description='Indicates if the operation was successful')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Contact ID')
        public String contactId;
        
        @InvocableVariable(label='Contact Name')
        public String contactName;
        
        @InvocableVariable(label='Email')
        public String email;
        
        @InvocableVariable(label='Account Name')
        public String accountName;
        
        @InvocableVariable(label='Error Message')
        public String errorMessage;
    }
}