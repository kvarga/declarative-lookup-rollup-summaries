/**
 * Copyright (c) 2013, Andrew Fawcett
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 *   are permitted provided that the following conditions are met:
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *      this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *      this list of conditions and the following disclaimer in the documentation 
 *      and/or other materials provided with the distribution.
 * - Neither the name of the FinancialForce.com, inc nor the names of its contributors 
 *      may be used to endorse or promote products derived from this software without 
 *      specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 *  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES 
 *  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
 *  THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
 *  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 *  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 *  OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

/**
 * Validation and other behaviour for the Lookup Rollup Summary custom object
 **/
public with sharing class RollupSummaries extends SObjectDomain
{
	/**
	 * Enum reflecting CalculationMode__c field picklist values
	 **/
	public enum CalculationMode
	{
		Realtime, 
		Scheduled, 
		Developer
	}
	
	/**
	 * Enum reflecting AggregateOperation__c field picklist values
	 **/
	public enum AggregateOperation 
	{
        Sum,
        Max, 
        Min,
        Avg,
        Count
    }
		
	public RollupSummaries(List<LookupRollupSummary__c> records)
	{
		super(records);
	}
	
	/**
	 * Validations for inserts and updates of records
	 **/ 
	public override void onValidate()
	{
		// Query for any related Apex triggers
		Set<String> rollupTriggerNames = new Set<String>();
		for(LookupRollupSummary__c lookupRollupSummary : (List<LookupRollupSummary__c>) Records)
			rollupTriggerNames.add(makeTriggerName(lookupRollupSummary));
		Map<String, ApexTrigger> apexTriggers = new ApexTriggersSelector().selectByName(rollupTriggerNames);

		// Cache Apex Describes		
		Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
		Map<SObjectType, Map<String, Schema.SObjectField>> gdFields = new Map<SObjectType, Map<String, Schema.SObjectField>>(); 	
		for(LookupRollupSummary__c lookupRollupSummary : (List<LookupRollupSummary__c>) Records)
		{
			SObjectType parentObjectType = gd.get(lookupRollupSummary.ParentObject__c);
			SObjectType childObjectType = gd.get(lookupRollupSummary.ChildObject__c);
			if(parentObjectType!=null && !gdFields.containsKey(parentObjectType))
				gdFields.put(parentObjectType, parentObjectType.getDescribe().fields.getMap());
			if(childObjectType!=null && !gdFields.containsKey(childObjectType))
				gdFields.put(childObjectType, childObjectType.getDescribe().fields.getMap());
		}
		
		for(LookupRollupSummary__c lookupRollupSummary : (List<LookupRollupSummary__c>) Records)
		{
			// TODO: Support Schedule mode
			if(lookupRollupSummary.CalculationMode__c == CalculationMode.Scheduled.name())
				lookupRollupSummary.CalculationMode__c.addError(error('Scheduled mode is not supported in this Beta.', lookupRollupSummary, LookupRollupSummary__c.CalculationMode__c));
			// Parent Object valid?
			SObjectType parentObjectType = gd.get(lookupRollupSummary.ParentObject__c);
			if(parentObjectType==null)
				lookupRollupSummary.ParentObject__c.addError(error('Object does not exist.', lookupRollupSummary, LookupRollupSummary__c.ParentObject__c));				
			// Child Object valid?
			SObjectType childObjectType = gd.get(lookupRollupSummary.ChildObject__c);
			if(childObjectType==null)
				lookupRollupSummary.ChildObject__c.addError(error('Object does not exist.', lookupRollupSummary, LookupRollupSummary__c.ChildObject__c));
			// Child Object fields valid?
			Map<String, Schema.SObjectField> childObjectFields = gdFields.get(childObjectType);
			if(childObjectFields!=null)
			{
				// Relationship field valid?
				if(!childObjectFields.containsKey(lookupRollupSummary.RelationshipField__c))
					lookupRollupSummary.RelationshipField__c.addError(error('Field does not exist.', lookupRollupSummary, LookupRollupSummary__c.RelationshipField__c));
				// Field to Aggregate valid?
				if(!childObjectFields.containsKey(lookupRollupSummary.FieldToAggregate__c))
					lookupRollupSummary.FieldToAggregate__c.addError(error('Field does not exist.', lookupRollupSummary, LookupRollupSummary__c.FieldToAggregate__c));
				// TODO: Validate relationship field is a lookup to the parent
				// ...
			}
			// Parent Object fields valid?
			Map<String, Schema.SObjectField> parentObjectFields = gdFields.get(parentObjectType);
			if(parentObjectFields!=null)
			{
				// Aggregate Result field valid?
				if(!parentObjectFields.containsKey(lookupRollupSummary.AggregateResultField__c))
					lookupRollupSummary.AggregateResultField__c.addError(error('Field does not exist.', lookupRollupSummary, LookupRollupSummary__c.AggregateResultField__c));
				// TODO: Aggregate Result field is compatible with the aggregate operation				
				// ...
			}						
			// Cannot activate Realtime rollup without the required trigger deployed
			String triggerName = makeTriggerName(lookupRollupSummary); 
			if(lookupRollupSummary.Active__c &&
			   lookupRollupSummary.CalculationMode__c == CalculationMode.Realtime.name() && 
			   !apexTriggers.containsKey(triggerName))
				lookupRollupSummary.Active__c.addError(error('Apex Trigger ' + triggerName + ' has not been deployed. Click Manage Child Trigger and try again.', lookupRollupSummary, LookupRollupSummary__c.Active__c));	
		}
	}
	
	public class Constructor implements SObjectDomain.IConstructable
	{
		public SObjectDomain construct(List<SObject> sObjectList)
		{
			return new RollupSummaries(sObjectList);
		}
	}	
	
	/**
	 * Trigger name for given lookup rollup summary
	 **/
	public static String makeTriggerName(LookupRollupSummary__c lookupRollupSummary)
	{
		if(Test.isRunningTest() && lookupRollupSummary.ChildObject__c == 'Opportunity')
			return 'RollupServiceTestTrigger';
		else		
			return 'dlrs_' + lookupRollupSummary.ChildObject__c.replace('__c', '').replace('__', '_') + 'Trigger';
	}
	
	/**
	 * Apex test name for given lookup rollup summary
	 **/
	public static String makeTriggerTestName(LookupRollupSummary__c lookupRollupSummary)
	{
		return 'dlrs_' + lookupRollupSummary.ChildObject__c.replace('__c', '').replace('__', '_') + 'Test';
	}
}