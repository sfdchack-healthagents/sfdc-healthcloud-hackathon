/**
 * @description Simple wrapper class for record output with only record ID
 * Author: Devi Pillai
 * Date: 2025-08-07
 * Version: 1.0
 */
public with sharing class AgentSFX_RecordOutputWrapper {
    
    @InvocableVariable(label='Record ID' description='The ID of the record')
    public String recId;
    
}