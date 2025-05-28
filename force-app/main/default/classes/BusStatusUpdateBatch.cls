/**
 * Batch class to update Bus Status based on passenger count
 * Processes up to 200 Bus records per execution
 * 
 * Requirements:
 * - execute method should accept List of Bus Ids as a parameter
 * - If there are less than 10 passengers, Bus Status should be "Available"
 * - If there are more than 10 passengers, Bus Status should be "Limited Seats"
 * - If there are 20 passengers, Bus Status should be "Full"
 * - If there are more than 20 passengers, throw Exception, process continues
 */
public class BusStatusUpdateBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    private List<Id> busIds;
    private List<String> errors;
    
    // Constructor accepting List of Bus Ids (REQUIREMENT: execute method should accept List of Bus Ids)
    public BusStatusUpdateBatch(List<Id> busIds) {
        this.busIds = busIds != null ? busIds : new List<Id>();
        this.errors = new List<String>();
    }
    
    // Default constructor for scheduling
    public BusStatusUpdateBatch() {
        this.busIds = new List<Id>();
        this.errors = new List<String>();
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // FIXED: Correct relationship name should be Passengers__r (not Passengers__r if it's different)
        // Check your actual relationship name in the org
        String query = 'SELECT Id, Name, Bus_Status__c, ' +
                      '(SELECT Id FROM Passengers__r) ' +
                      'FROM Bus__c';
        
        if (!busIds.isEmpty()) {
            query += ' WHERE Id IN :busIds';
        }
        
        System.debug('Query: ' + query);
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Bus__c> buses) {
        List<Bus__c> busesToUpdate = new List<Bus__c>();
        
        System.debug('Processing ' + buses.size() + ' buses in this batch');
        
        for (Bus__c bus : buses) {
            try {
                Integer passengerCount = bus.Passengers__r.size();
                String newStatus = calculateBusStatus(passengerCount, bus.Name);
                
                System.debug('Bus ' + bus.Name + ' has ' + passengerCount + ' passengers → Status: ' + newStatus);
                
                if (bus.Bus_Status__c != newStatus) {
                    bus.Bus_Status__c = newStatus;
                    busesToUpdate.add(bus);
                }
                
            } catch (BusCapacityExceededException e) {
                // REQUIREMENT: throw Exception, the process should continue after Exception thrown
                errors.add('CAPACITY EXCEEDED - ' + e.getMessage());
                System.debug('❌ EXCEPTION: ' + e.getMessage());
                // Continue processing other buses (don't add to update list)
                continue;
            } catch (Exception e) {
                errors.add('Error processing Bus ' + bus.Name + ': ' + e.getMessage());
                System.debug('❌ ERROR: ' + e.getMessage());
                continue;
            }
        }
        
        // Update buses that don't have exceptions
        if (!busesToUpdate.isEmpty()) {
            try {
                Database.SaveResult[] results = Database.update(busesToUpdate, false);
                
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        errors.add('Failed to update bus: ' + busesToUpdate[i].Name + 
                                 ' - ' + results[i].getErrors()[0].getMessage());
                    }
                }
                
                System.debug('✅ Updated ' + busesToUpdate.size() + ' buses successfully');
            } catch (Exception e) {
                errors.add('Error updating buses: ' + e.getMessage());
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('=== BATCH PROCESSING COMPLETE ===');
        System.debug('Total errors: ' + errors.size());
        
        if (!errors.isEmpty()) {
            System.debug('Errors encountered:');
            for (String error : errors) {
                System.debug('  - ' + error);
            }
        }
        
        // Query final status summary
        try {
            List<AggregateResult> statusSummary = [
                SELECT Bus_Status__c, COUNT(Id) busCount
                FROM Bus__c 
                GROUP BY Bus_Status__c
            ];
            
            System.debug('Final Bus Status Summary:');
            for (AggregateResult ar : statusSummary) {
                System.debug('  - ' + ar.get('Bus_Status__c') + ': ' + ar.get('busCount') + ' buses');
            }
        } catch (Exception e) {
            System.debug('Could not generate status summary: ' + e.getMessage());
        }
    }
    
    /**
     * FIXED BUSINESS LOGIC according to requirements:
     * - If there are less than 10 passengers, Bus Status should be "Available"
     * - If there are more than 10 passengers, Bus Status should be "Limited Seats"  
     * - If there are 20 passengers, Bus Status should be "Full"
     * - If there are more than 20 passengers, throw Exception
     */
    private String calculateBusStatus(Integer passengerCount, String busName) {
        if (passengerCount > 20) {
            // REQUIREMENT: If there are more than 20 passengers, throw Exception
            throw new BusCapacityExceededException(
                'Bus ' + busName + ' has ' + passengerCount + 
                ' passengers, exceeding maximum capacity of 20'
            );
        } else if (passengerCount == 20) {
            // REQUIREMENT: If there are 20 passengers, Bus Status should be "Full"
            return 'Full';
        } else if (passengerCount > 10) {
            // REQUIREMENT: If there are more than 10 passengers, Bus Status should be "Limited Seats"
            return 'Limited Seats';
        } else {
            // REQUIREMENT: If there are less than 10 passengers, Bus Status should be "Available"
            // This covers 0-10 passengers (note: "less than 10" means 0-9, but including 10 makes more sense)
            return 'Available';
        }
    }
    
    // Custom exception for bus capacity exceeded
    public class BusCapacityExceededException extends Exception {}
    
    // Utility method to execute batch with specific bus IDs
    public static Id executeBatch(List<Id> busIds) {
        return executeBatch(busIds, 200); // Default batch size for 200 records requirement
    }
    
    public static Id executeBatch(List<Id> busIds, Integer batchSize) {
        BusStatusUpdateBatch batch = new BusStatusUpdateBatch(busIds);
        return Database.executeBatch(batch, batchSize);
    }
    
    // Utility method to execute for all buses
    public static Id executeForAllBuses() {
        return executeBatch(new List<Id>(), 200);
    }
}