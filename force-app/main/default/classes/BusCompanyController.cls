public with sharing class BusCompanyController {
    
    @AuraEnabled(cacheable=true)
    public static List<Bus__c> getBusesWithPassengers(Id companyId) {
        try {
            return [
                SELECT Id, Name, Bus_Status__c,
                       (SELECT Id, Name, Email__c, Phone__c FROM Passengers__r ORDER BY Name)
                FROM Bus__c 
                WHERE Bus_Company__c = :companyId
                ORDER BY Name
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving buses: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateBusStatuses(Id companyId) {
        try {
            List<Bus__c> companyBuses = [SELECT Id FROM Bus__c WHERE Bus_Company__c = :companyId];
            List<Id> busIds = new List<Id>();
            
            for (Bus__c bus : companyBuses) {
                busIds.add(bus.Id);
            }
            
            if (!busIds.isEmpty()) {
                BusStatusUpdateBatch.executeBatch(busIds);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error updating bus statuses: ' + e.getMessage());
        }
    }
}