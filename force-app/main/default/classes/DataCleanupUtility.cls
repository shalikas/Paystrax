/**
 * Utility class to clean up test data in the correct order
 * Deletes: Passenger__c → Bus__c → Bus_Company__c
 * Respects foreign key relationships to avoid errors
 */
public class DataCleanupUtility {
    
    /**
     * Clean all test data - use with caution!
     * Deletes ALL records from Passenger__c, Bus__c, and Bus_Company__c
     */
    public static void cleanAllData() {
        System.debug('=== STARTING COMPLETE DATA CLEANUP ===');
        
        // Step 1: Delete Passengers first (they reference Bus__c)
        cleanPassengers();
        
        // Step 2: Delete Buses (they reference Bus_Company__c)  
        cleanBuses();
        
        // Step 3: Delete Bus Companies last (no dependencies)
        cleanBusCompanies();
        
        System.debug('=== DATA CLEANUP COMPLETE ===');
        generateCleanupSummary();
    }
    
    /**
     * Clean only Passengers (useful for testing different passenger scenarios)
     */
    public static void cleanPassengers() {
        try {
            List<Passenger__c> passengers = [SELECT Id FROM Passenger__c];
            
            if (!passengers.isEmpty()) {
                System.debug('🧹 Deleting ' + passengers.size() + ' Passengers...');
                
                // Delete in batches to handle large datasets
                Integer batchSize = 10000;
                Integer totalDeleted = 0;
                
                for (Integer i = 0; i < passengers.size(); i += batchSize) {
                    Integer endIndex = Math.min(i + batchSize, passengers.size());
                    List<Passenger__c> batch = new List<Passenger__c>();
                    
                    for (Integer j = i; j < endIndex; j++) {
                        batch.add(passengers[j]);
                    }
                    
                    delete batch;
                    totalDeleted += batch.size();
                    System.debug('  Deleted: ' + totalDeleted + '/' + passengers.size());
                }
                
                System.debug('✅ Deleted ' + totalDeleted + ' Passengers');
            } else {
                System.debug('ℹ️  No Passengers to delete');
            }
        } catch (Exception e) {
            System.debug('❌ Error deleting Passengers: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Clean only Buses (and their passengers if any remain)
     */
    public static void cleanBuses() {
        try {
            List<Bus__c> buses = [SELECT Id FROM Bus__c];
            
            if (!buses.isEmpty()) {
                System.debug('🧹 Deleting ' + buses.size() + ' Buses...');
                
                // Delete in batches
                Integer batchSize = 2000;
                Integer totalDeleted = 0;
                
                for (Integer i = 0; i < buses.size(); i += batchSize) {
                    Integer endIndex = Math.min(i + batchSize, buses.size());
                    List<Bus__c> batch = new List<Bus__c>();
                    
                    for (Integer j = i; j < endIndex; j++) {
                        batch.add(buses[j]);
                    }
                    
                    delete batch;
                    totalDeleted += batch.size();
                    System.debug('  Deleted: ' + totalDeleted + '/' + buses.size());
                }
                
                System.debug('✅ Deleted ' + totalDeleted + ' Buses');
            } else {
                System.debug('ℹ️  No Buses to delete');
            }
        } catch (Exception e) {
            System.debug('❌ Error deleting Buses: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Clean only Bus Companies
     */
    public static void cleanBusCompanies() {
        try {
            List<Bus_Company__c> companies = [SELECT Id FROM Bus_Company__c];
            
            if (!companies.isEmpty()) {
                System.debug('🧹 Deleting ' + companies.size() + ' Bus Companies...');
                delete companies;
                System.debug('✅ Deleted ' + companies.size() + ' Bus Companies');
            } else {
                System.debug('ℹ️  No Bus Companies to delete');
            }
        } catch (Exception e) {
            System.debug('❌ Error deleting Bus Companies: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Clean specific objects by IDs
     */
    public static void cleanPassengersByIds(List<Id> passengerIds) {
        if (passengerIds == null || passengerIds.isEmpty()) {
            System.debug('ℹ️  No Passenger IDs provided');
            return;
        }
        
        try {
            List<Passenger__c> passengers = [SELECT Id FROM Passenger__c WHERE Id IN :passengerIds];
            if (!passengers.isEmpty()) {
                delete passengers;
                System.debug('✅ Deleted ' + passengers.size() + ' specific Passengers');
            }
        } catch (Exception e) {
            System.debug('❌ Error deleting specific Passengers: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void cleanBusesByIds(List<Id> busIds) {
        if (busIds == null || busIds.isEmpty()) {
            System.debug('ℹ️  No Bus IDs provided');
            return;
        }
        
        try {
            // First delete related passengers
            List<Passenger__c> relatedPassengers = [SELECT Id FROM Passenger__c WHERE Bus__c IN :busIds];
            if (!relatedPassengers.isEmpty()) {
                delete relatedPassengers;
                System.debug('✅ Deleted ' + relatedPassengers.size() + ' related Passengers');
            }
            
            // Then delete the buses
            List<Bus__c> buses = [SELECT Id FROM Bus__c WHERE Id IN :busIds];
            if (!buses.isEmpty()) {
                delete buses;
                System.debug('✅ Deleted ' + buses.size() + ' specific Buses');
            }
        } catch (Exception e) {
            System.debug('❌ Error deleting specific Buses: ' + e.getMessage());
            throw e;
        }
    }
    
    public static void cleanCompaniesByIds(List<Id> companyIds) {
        if (companyIds == null || companyIds.isEmpty()) {
            System.debug('ℹ️  No Company IDs provided');
            return;
        }
        
        try {
            // First delete related buses and passengers
            List<Bus__c> relatedBuses = [SELECT Id FROM Bus__c WHERE Bus_Company__c IN :companyIds];
            if (!relatedBuses.isEmpty()) {
                List<Id> busIds = new List<Id>();
                for (Bus__c bus : relatedBuses) {
                    busIds.add(bus.Id);
                }
                cleanBusesByIds(busIds);
            }
            
            // Then delete the companies
            List<Bus_Company__c> companies = [SELECT Id FROM Bus_Company__c WHERE Id IN :companyIds];
            if (!companies.isEmpty()) {
                delete companies;
                System.debug('✅ Deleted ' + companies.size() + ' specific Bus Companies');
            }
        } catch (Exception e) {
            System.debug('❌ Error deleting specific Bus Companies: ' + e.getMessage());
            throw e;
        }
    }
    
    /**
     * Generate summary of remaining data after cleanup
     */
    public static void generateCleanupSummary() {
        try {
            Integer passengerCount = [SELECT COUNT() FROM Passenger__c];
            Integer busCount = [SELECT COUNT() FROM Bus__c];
            Integer companyCount = [SELECT COUNT() FROM Bus_Company__c];
            
            System.debug('');
            System.debug('📊 CLEANUP SUMMARY:');
            System.debug('  Remaining Passengers: ' + passengerCount);
            System.debug('  Remaining Buses: ' + busCount);
            System.debug('  Remaining Bus Companies: ' + companyCount);
            
            if (passengerCount == 0 && busCount == 0 && companyCount == 0) {
                System.debug('✅ ALL DATA CLEANED SUCCESSFULLY!');
            } else {
                System.debug('⚠️  Some data remains - check for deletion restrictions');
            }
        } catch (Exception e) {
            System.debug('❌ Error generating cleanup summary: ' + e.getMessage());
        }
    }
    
    /**
     * Safe cleanup with confirmation - prevents accidental deletion
     */
    public static void safeCleanAllData(String confirmationCode) {
        if (confirmationCode != 'DELETE_ALL_TEST_DATA') {
            System.debug('❌ SAFETY CHECK FAILED');
            System.debug('⚠️  To delete all data, call: DataCleanupUtility.safeCleanAllData(\'DELETE_ALL_TEST_DATA\')');
            return;
        }
        
        System.debug('⚠️  CONFIRMED: Deleting all test data...');
        cleanAllData();
    }
    
    /**
     * Quick method to reset and prepare for new test data
     */
    public static void resetForNewTests() {
        System.debug('🔄 RESETTING FOR NEW TESTS...');
        cleanAllData();
        System.debug('✅ Ready for new test data creation!');
    }
}