import { type ClientSchema, a, defineData } from "@aws-amplify/backend";

/*
 * Define your data models here.
 * 
 * Example:
 *   MyModel: a.model({
 *     name: a.string().required(),
 *     description: a.string(),
 *     done: a.boolean().required(),
 *   }).authorization((allow) => [allow.publicApiKey()]),
 *
 * Relationships:
 *   Parent: a.model({
 *     name: a.string().required(),
 *     children: a.hasMany("Child", "parentId"),
 *   }).authorization((allow) => [allow.publicApiKey()]),
 *
 *   Child: a.model({
 *     title: a.string().required(),
 *     parentId: a.id().required(),        // MUST use a.id(), NOT a.string()
 *     parent: a.belongsTo("Parent", "parentId"),  // MUST declare both sides
 *   }).authorization((allow) => [allow.publicApiKey()]),
 */

const schema = a.schema({
  // Replace with your own models:
  Example: a.model({
    name: a.string().required(),
    description: a.string(),
    done: a.boolean().required(),
  }).authorization((allow) => [allow.publicApiKey()]),
});

export type Schema = ClientSchema<typeof schema>;

export const data = defineData({
  schema,
  authorizationModes: {
    defaultAuthorizationMode: "apiKey",
    apiKeyAuthorizationMode: {
      expiresInDays: 30,
    },
  },
});
