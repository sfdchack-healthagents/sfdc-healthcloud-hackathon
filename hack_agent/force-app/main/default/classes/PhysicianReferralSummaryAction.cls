/**
 * @description Invocable Apex action for Prompt Builder / Flow
 * Queries ClinicalServiceRequest records where the given HealthcareProvider
 * is the Requester, and returns a formatted referral summary string
 */
public with sharing class PhysicianReferralSummaryAction {

    public class Request {
        @InvocableVariable(required=true label='Healthcare Provider ID')
        public Id providerId;
    }

    public class Response {
        @InvocableVariable(label='Referral Summary')
        public String referralSummary;
    }

    @InvocableMethod(label='Get Physician Referral Summary' 
                     description='Returns a formatted summary of all referrals made by a Healthcare Provider')
    public static List<Response> getReferralSummary(List<Request> requests) {
        List<Response> responses = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            res.referralSummary = buildSummary(req.providerId);
            responses.add(res);
        }

        return responses;
    }

    private static String buildSummary(Id providerId) {
        // Get provider details
        List<HealthcareProvider> providers = [
            SELECT Id, Name,
                   Practitioner.Name, Practitioner.Email, Practitioner.Phone,
                   Practitioner.Title, Practitioner.Department,
                   Account.Name
            FROM HealthcareProvider
            WHERE Id = :providerId
            LIMIT 1
        ];

        if (providers.isEmpty()) {
            return 'No Healthcare Provider found for the given ID.';
        }

        HealthcareProvider provider = providers[0];
        String summary = '';

        // Provider details
        summary += '=== PHYSICIAN DETAILS ===\n';
        summary += 'Provider Name: ' + safe(provider.Name) + '\n';
        summary += 'Contact Name: ' + safe(provider.Practitioner?.Name) + '\n';
        summary += 'Title: ' + safe(provider.Practitioner?.Title) + '\n';
        summary += 'Department: ' + safe(provider.Practitioner?.Department) + '\n';
        summary += 'Email: ' + safe(provider.Practitioner?.Email) + '\n';
        summary += 'Phone: ' + safe(provider.Practitioner?.Phone) + '\n';
        summary += 'Clinic/Account: ' + safe(provider.Account?.Name) + '\n\n';

        // Referrals made by this provider (as Requester)
        List<ClinicalServiceRequest> referrals = [
            SELECT Id, Name, Status, Priority, Type, StartDate, EndDate,
                   Patient.Name, Facility.Name,
                   PatientInstruction, CreatedDate
            FROM ClinicalServiceRequest
            WHERE RequesterId = :providerId
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        summary += '=== REFERRAL HISTORY (as Requester) ===\n';
        summary += 'Total Referrals: ' + referrals.size() + '\n\n';

        if (referrals.isEmpty()) {
            summary += 'No referral records found for this provider.\n\n';
        } else {
            // Status breakdown
            Map<String, Integer> statusCount = new Map<String, Integer>();
            Map<String, Integer> priorityCount = new Map<String, Integer>();
            Map<String, Integer> typeCount = new Map<String, Integer>();
            Map<String, Integer> facilityCount = new Map<String, Integer>();
            Date earliestDate;
            Date latestDate;

            for (ClinicalServiceRequest csr : referrals) {
                String status = csr.Status != null ? csr.Status : 'Unknown';
                statusCount.put(status, (statusCount.containsKey(status) ? statusCount.get(status) : 0) + 1);

                String priority = csr.Priority != null ? csr.Priority : 'Unknown';
                priorityCount.put(priority, (priorityCount.containsKey(priority) ? priorityCount.get(priority) : 0) + 1);

                String csrType = csr.Type != null ? csr.Type : 'Unknown';
                typeCount.put(csrType, (typeCount.containsKey(csrType) ? typeCount.get(csrType) : 0) + 1);

                String facility = csr.Facility?.Name != null ? csr.Facility.Name : 'Unknown';
                facilityCount.put(facility, (facilityCount.containsKey(facility) ? facilityCount.get(facility) : 0) + 1);

                Date csrDate = csr.CreatedDate.date();
                if (earliestDate == null || csrDate < earliestDate) earliestDate = csrDate;
                if (latestDate == null || csrDate > latestDate) latestDate = csrDate;
            }

            // Status breakdown
            summary += '-- Status Breakdown --\n';
            for (String s : statusCount.keySet()) {
                summary += '  ' + s + ': ' + statusCount.get(s) + '\n';
            }

            // Priority breakdown
            summary += '\n-- Priority Breakdown --\n';
            for (String p : priorityCount.keySet()) {
                summary += '  ' + p + ': ' + priorityCount.get(p) + '\n';
            }

            // Type breakdown
            summary += '\n-- Type Breakdown --\n';
            for (String t : typeCount.keySet()) {
                summary += '  ' + t + ': ' + typeCount.get(t) + '\n';
            }

            // Facility breakdown
            summary += '\n-- Top Facilities Referred To --\n';
            for (String f : facilityCount.keySet()) {
                summary += '  ' + f + ': ' + facilityCount.get(f) + ' referrals\n';
            }

            // Date range
            summary += '\n-- Referral Timeline --\n';
            summary += '  Earliest: ' + (earliestDate != null ? String.valueOf(earliestDate) : 'N/A') + '\n';
            summary += '  Latest: ' + (latestDate != null ? String.valueOf(latestDate) : 'N/A') + '\n';

            // Recent referrals detail
            summary += '\n-- Recent Referrals (up to 10) --\n';
            Integer count = 0;
            for (ClinicalServiceRequest csr : referrals) {
                if (count >= 10) break;
                count++;
                summary += count + '. ' + safe(csr.Name);
                summary += ' | Status: ' + safe(csr.Status);
                summary += ' | Priority: ' + safe(csr.Priority);
                summary += ' | Type: ' + safe(csr.Type);
                summary += ' | Patient: ' + safe(csr.Patient?.Name);
                summary += ' | Facility: ' + safe(csr.Facility?.Name);
                summary += ' | Date: ' + (csr.CreatedDate != null ? String.valueOf(csr.CreatedDate.date()) : 'N/A');
                summary += '\n';
            }
        }

        // Services performed by this provider
        List<ClinicalServiceRequest> performed = [
            SELECT Id, Name, Status, StartDate, Patient.Name, CreatedDate
            FROM ClinicalServiceRequest
            WHERE PerformerId = :providerId
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];

        summary += '\n=== SERVICES PERFORMED (as Performer) ===\n';
        summary += 'Total: ' + performed.size() + '\n';
        if (!performed.isEmpty()) {
            Integer pCount = 0;
            for (ClinicalServiceRequest csr : performed) {
                if (pCount >= 5) break;
                pCount++;
                summary += pCount + '. ' + safe(csr.Name);
                summary += ' | Status: ' + safe(csr.Status);
                summary += ' | Patient: ' + safe(csr.Patient?.Name);
                summary += ' | Date: ' + (csr.CreatedDate != null ? String.valueOf(csr.CreatedDate.date()) : 'N/A');
                summary += '\n';
            }
        }

        // Recent activities on the provider's contact
        if (provider.Practitioner != null) {
            List<Task> recentTasks = [
                SELECT Subject, Status, ActivityDate, Description
                FROM Task
                WHERE WhoId = :provider.PractitionerId
                ORDER BY ActivityDate DESC
                LIMIT 5
            ];

            summary += '\n=== RECENT ENGAGEMENT ACTIVITIES ===\n';
            summary += 'Total Recent Activities: ' + recentTasks.size() + '\n';
            for (Task t : recentTasks) {
                summary += '- ' + safe(t.Subject);
                summary += ' | Status: ' + safe(t.Status);
                summary += ' | Date: ' + (t.ActivityDate != null ? String.valueOf(t.ActivityDate) : 'N/A');
                summary += '\n';
            }
        }

        return summary;
    }

    private static String safe(String val) {
        return String.isNotBlank(val) ? val : 'N/A';
    }
}