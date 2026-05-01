/**
 * @description Invocable Apex action for Prompt Builder
 * Finds HealthcareProvider records by name or email
 */
public with sharing class ContactFinder {

    public class Request {
        @InvocableVariable(required=true label='Search Name')
        public String searchName;
        
        @InvocableVariable(label='Search Email')
        public String searchEmail;
    }

    public class Response {
        @InvocableVariable(label='Healthcare Provider ID')
        public String healthcareProviderId;
    }

    @InvocableMethod(label='Find Healthcare Provider' 
                     description='Searches for HealthcareProvider records by name or email')
    public static List<Response> findContact(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res = searchHealthcareProvider(req.searchName, req.searchEmail);
            responses.add(res);
        }

        return responses;
    }

    private static Response searchHealthcareProvider(String searchName, String searchEmail) {
        Response result = new Response();
        
        try {
            List<HealthcareProvider> providers = new List<HealthcareProvider>();
            
            // Use SOSL for fuzzy matching directly on HealthcareProvider
            if (String.isNotBlank(searchName)) {
                List<List<SObject>> searchResults = [
                    FIND :searchName 
                    RETURNING HealthcareProvider(Id, Name LIMIT 1)
                ];
                
                if (!searchResults.isEmpty() && !searchResults[0].isEmpty()) {
                    providers = (List<HealthcareProvider>) searchResults[0];
                }
            }
            
            // Fallback: if no results by name, try email if provided
            if (providers.isEmpty() && String.isNotBlank(searchEmail)) {
                List<List<SObject>> emailSearchResults = [
                    FIND :searchEmail 
                    RETURNING HealthcareProvider(Id, Name LIMIT 1)
                ];
                
                if (!emailSearchResults.isEmpty() && !emailSearchResults[0].isEmpty()) {
                    providers = (List<HealthcareProvider>) emailSearchResults[0];
                }
            }
            
            // Populate response with provider ID
            if (!providers.isEmpty()) {
                result.healthcareProviderId = providers[0].Id;
                System.debug('DEBUG: Found healthcare provider: ' + providers[0].Id);
            } else {
                System.debug('DEBUG: No healthcare provider found for search criteria');
            }
            
        } catch (Exception e) {
            System.debug('Error in searchHealthcareProvider: ' + e.getMessage());
        }
        
        return result;
    }
}