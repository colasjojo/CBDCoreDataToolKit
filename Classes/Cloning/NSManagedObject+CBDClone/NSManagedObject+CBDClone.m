#import "NSManagedObject+CBDClone.h"

@implementation NSManagedObject (CBDClone)



#define COMMENTS_ON 0

int numberOfEntitiesCopied = 0;


//
//
/**************************************/
#pragma mark - Core methods
/**************************************/




- (NSManagedObject *)cloneInContext:(NSManagedObjectContext *)context
                    withCopiedCache:(NSMutableDictionary *)alreadyCopied
                     exludeEntities:(NSArray *)namesOfEntitiesToExclude
                  excludeAttributes:(NSArray *)namesOfAttributesToExclude
          excludeRelationships_cbd_:(NSArray *)namesOfRelationshipsToExclude
{
    numberOfEntitiesCopied = numberOfEntitiesCopied + 1;
    
    if (numberOfEntitiesCopied >= 10)
    {
        [context performBlock:
         ^{
             NSError *error;
             [context save:&error];
         }];
        
        numberOfEntitiesCopied = 0;
    }
    
    NSString *entityName = [[self entity] name];
    
#if (COMMENTS_ON)
    NSLog(@"Cloning a NSManagedObject of type %@", entityName);
    NSLog(@"  | entitities excluded from cloning : %@", namesOfEntitiesToExclude);
    NSLog(@"  | attributes excluded from cloning : %@", namesOfAttributesToExclude);
    NSLog(@"  | size of the cache : %ld", [alreadyCopied count]);
#endif
    
    if ([namesOfEntitiesToExclude containsObject:entityName])
    {
        
#if (COMMENTS_ON)
        NSLog(@"  | ¡ objet not copied !");
        NSLog(@"  | (because its entitity is excluded of the copy)");
#endif
        
        return nil;
    }
    
    __block NSManagedObject *cloned = [alreadyCopied objectForKey:[self objectID]];
    if (cloned != nil)
    {
        
#if (COMMENTS_ON)
        NSLog(@"  | ¡ objet not copied !");
        NSLog(@"  | (because it is the cache)");
#endif
        
        return cloned;
    }
    
    
    
    //create new object in data store
    [context performBlockAndWait:
     ^{
         cloned = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                inManagedObjectContext:context];
         [alreadyCopied setObject:cloned
                           forKey:[self objectID]];
     }];
    
    
    
    
    //loop through all attributes and assign then to the clone
    NSDictionary *attributes = [[NSEntityDescription entityForName:entityName
                                            inManagedObjectContext:context] attributesByName];
    
#if (COMMENTS_ON)
    NSLog(@"Copying the attributes : ");
#endif
    
    for (NSString *attr in attributes)
    {
        if (![namesOfAttributesToExclude containsObject:attr])
        {
            [context performBlockAndWait:
             ^{
                 [cloned setValue:[self valueForKey:attr] forKey:attr];
             }];
#if (COMMENTS_ON)
            NSLog(@"  | the attribute %@ gets the value %@ ", attr, [self valueForKey:attr]);
#endif
            
        }
    }
    
    //Loop through all relationships, and clone them.
    NSDictionary *relationships = [[NSEntityDescription entityForName:entityName
                                               inManagedObjectContext:context] relationshipsByName];
    
#if (COMMENTS_ON)
    NSLog(@"Taking account of the relationships : ");
#endif
    
    for (NSString *relName in [relationships allKeys])
    {
        NSRelationshipDescription *rel = [relationships objectForKey:relName];
        
        NSString *keyName = rel.name;
        
#if (COMMENTS_ON)
        NSLog(@"  | Relationships '%@'", keyName);
#endif
        
        if (![namesOfRelationshipsToExclude containsObject:relName])
        {
            [context performBlockAndWait:
             ^{
                 if ([rel isToMany])
                 {
                     id sourceSet;
                     id clonedSet;
                     
                     /*
                      On gère selon que la relation est ordonnée ou non
                      */
                     if (![rel isOrdered])
                     {
                         //get a set of all objects in the relationship
                         sourceSet = [self mutableSetValueForKey:keyName];
                         clonedSet = [cloned mutableSetValueForKey:keyName];
                     }
                     else
                     {
                         sourceSet = [self mutableOrderedSetValueForKey:keyName];
                         clonedSet = [cloned mutableOrderedSetValueForKey:keyName];
                     }
                     
                     NSEnumerator *e = [sourceSet objectEnumerator];
                     NSManagedObject *relatedObject;
                     
                     while (relatedObject = [e nextObject])
                     {
                         //Clone it, and add clone to set
                         NSManagedObject *clonedRelatedObject = [relatedObject cloneInContext:context
                                                                              withCopiedCache:alreadyCopied
                                                                               exludeEntities:namesOfEntitiesToExclude
                                                                       excludeAttributes_cbd_:namesOfAttributesToExclude];
                         if (clonedRelatedObject)
                         {
                             [clonedSet addObject:clonedRelatedObject];
                         }
                     }
                 }
                 else
                 {
                     NSManagedObject *relatedObject = [self valueForKey:keyName];
                     if (relatedObject != nil)
                     {
                         NSManagedObject *clonedRelatedObject = [relatedObject cloneInContext:context
                                                                              withCopiedCache:alreadyCopied
                                                                               exludeEntities:namesOfEntitiesToExclude
                                                                       excludeAttributes_cbd_:namesOfAttributesToExclude];
                         if (clonedRelatedObject)
                         {
                             [cloned setValue:clonedRelatedObject forKey:keyName];
                         }
                     }
                 }
             }];
        }
    }
    
    return cloned;
}






//
//
/**************************************/
#pragma mark - Convenience methods
/**************************************/



- (NSManagedObject *)cloneInContext:(NSManagedObjectContext *)context
                    withCopiedCache:(NSMutableDictionary *)alreadyCopied
                     exludeEntities:(NSArray *)namesOfEntitiesToExclude
             excludeAttributes_cbd_:(NSArray *)namesOfAttributesToExclude
{
    return [self cloneInContext:context
                withCopiedCache:alreadyCopied
                 exludeEntities:namesOfEntitiesToExclude
              excludeAttributes:namesOfAttributesToExclude
      excludeRelationships_cbd_:@[]];
}



- (NSManagedObject *)cloneToContext:(NSManagedObjectContext *)context
                exludeEntities_cbd_:(NSArray *)namesOfEntitiesToExclude
{
    return [self cloneInContext:context
                withCopiedCache:[NSMutableDictionary dictionary]
                 exludeEntities:namesOfEntitiesToExclude
         excludeAttributes_cbd_:@[]];
}







- (NSManagedObject *)cloneToContext:(NSManagedObjectContext *)context
                     exludeEntities:(NSArray *)namesOfEntitiesToExclude
             excludeAttributes_cbd_:(NSArray *)namesOfAttributesToExclude
{
    return [self cloneInContext:context
                withCopiedCache:[NSMutableDictionary dictionary]
                 exludeEntities:namesOfEntitiesToExclude
         excludeAttributes_cbd_:namesOfAttributesToExclude];
}




//
//
/**************************************/
#pragma mark - Others methods (filling, etc.)
/**************************************/



- (void) fillInAttributesFrom:(NSManagedObject *)sourceObject
        exludeAttributes_cbd_:(NSArray *)namesOfAttributesToExclude
{
    NSMutableArray *arrayOfAttributesToInclude = [[sourceObject.entity.attributesByName allKeys] mutableCopy];
    [arrayOfAttributesToInclude removeObjectsInArray:namesOfAttributesToExclude];
    
    [self fillInAttributesFrom:sourceObject
           onlyAttributes_cbd_:arrayOfAttributesToInclude];
}




- (void) fillInAttributesFrom:(NSManagedObject *)sourceObject
          onlyAttributes_cbd_:(NSArray *)namesOfAttributesToCopy
{
    NSManagedObjectContext *contextSource = [sourceObject managedObjectContext];
    NSString *sourceEntityName = [[sourceObject entity] name];
    
    
    //loop through all attributes and assign then to the clone
    NSDictionary *attributes = [[NSEntityDescription entityForName:sourceEntityName
                                            inManagedObjectContext:contextSource] attributesByName];
    
    for (NSString *attr in attributes)
    {
        if ([namesOfAttributesToCopy containsObject:attr])
        {
            [self setValue:[sourceObject valueForKey:attr] forKey:attr];
        }
    }
    
}





- (NSManagedObject *)cloneOnlyAttribuesToContext:(NSManagedObjectContext *)context
                           exludeAttributes_cbd_:(NSArray *)namesOfAttributesToExclude
{
    NSString *entityName = [[self entity] name];
    
    __block NSManagedObject *cloned;
    
    [context performBlockAndWait:^{
        cloned = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                                 inManagedObjectContext:context];
        
        //loop through all attributes and assign then to the clone
        NSDictionary *attributes = [[NSEntityDescription entityForName:entityName
                                                inManagedObjectContext:context] attributesByName];
        
        for (NSString *attr in attributes)
        {
            if (![namesOfAttributesToExclude containsObject:attr])
            {
                [cloned setValue:[self valueForKey:attr] forKey:attr];
            }
        }

    }];
    
    return cloned;
}



@end