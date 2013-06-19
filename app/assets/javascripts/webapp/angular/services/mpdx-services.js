'use strict';

/* Filters */

angular.module('mpdxServices', ['ngResource'])
.factory('Contact', function($resource){
  return $resource('/api/v1/contacts/:contactId', {access_token:'243857230498572349898798'}, {
    query:{method:'GET', params: {includes:"addresses"} },
    pledge_frequencies:{method:'GET', params: {contactId:"pledge_frequencies"}} });
}).factory('Person', function($resource){
  return $resource('/api/v1/contacts/:contactId/people/:personId', {access_token:'243857230498572349898798'});
}).factory('Donation', function($resource){
  return $resource('/api/v1/contacts/:contactId/donations', {access_token:'243857230498572349898798'}, { query:{method:'GET'} });
});
