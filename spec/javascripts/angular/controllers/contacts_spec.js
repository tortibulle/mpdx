describe('contacts', function() {
    beforeEach(module('mpdxApp'));
    var $scope, $location, $rootScope, createController;

    beforeEach(inject(function($injector) {
        $location = $injector.get('$location');
        $rootScope = $injector.get('$rootScope');
        $httpBackend = $injector.get('$httpBackend');
        $scope = $rootScope.$new();

        var $controller = $injector.get('$controller');

        createController = function() {
            return $controller('contactsController', {
                '$scope': $scope,
                '$http': $httpBackend
            });
        };
    }));


    it('reset filter should clear filters', function() {
        var controller = createController();

        $scope.contactQuery.tags = ['test'];
        $scope.contactQuery.name = 'Steve';
        $scope.contactQuery.type = 'person';
        $scope.contactQuery.city = ['Green Bay'];
        $scope.contactQuery.state = ['WI'];
        $scope.contactQuery.newsletter = 'all';
        $scope.contactQuery.status = ['test'];
        $scope.contactQuery.likely = ['test'];
        $scope.contactQuery.church = ['First Church', 'Second Church'];
        $scope.contactQuery.referrer = ['-'];

        $scope.resetFilters();

        expect($scope.contactQuery.tags).toEqual(['']);
        expect($scope.contactQuery.name).toEqual('');
        expect($scope.contactQuery.type).toEqual('');
        expect($scope.contactQuery.city).toEqual(['']);
        expect($scope.contactQuery.state).toEqual(['']);
        expect($scope.contactQuery.newsletter).toEqual('');
        expect($scope.contactQuery.status).toEqual(['']);
        expect($scope.contactQuery.likely).toEqual(['']);
        expect($scope.contactQuery.church).toEqual(['']);
        expect($scope.contactQuery.referrer).toEqual(['']);
    });

    it('url array encode should encode vars', function() {
        var controller = createController();

        var array = ['Testing', '$T$%&^V3'];
        var encoded = encodeURLarray(array);

        expect(encoded[0]).toEqual('Testing');
        expect(encoded[1]).toEqual('%24T%24%25%26%5EV3');
    });

    it('contact api should return 1 contact', function() {
        var controller = createController();

        window.current_account_list_id = 1;

        //get user view filters
        $httpBackend.when("GET", "/api/v1/users/me").respond({"user": {"preferences": {"contacts_filter": {"1": {"tags": "", "name": "", "type": "", "city": [""], "state": [""], "newsletter": "", "status": [""], "likely": [""], "church": [""], "referrer": [""]}, "2": {"tags": "", "name": "", "type": "", "city": [""], "state": [""], "newsletter": "all", "status": [""], "likely": [""], "church": [""], "referrer": [""]}}, "contacts_view_options": {}, "time_zone": "Atlantic Time (Canada)", "default_account_list": 1}, "created_at": "2014-04-15T15:49:11.229-03:00", "updated_at": "2014-05-15T12:50:26.113-03:00", "account_list_ids": [1, 2]}}, {});

        //return contact
        $httpBackend.when("GET", /^\/api\/v1\/contacts\?.*/).respond({"people":[{"id":59,"first_name":"Buzz","last_name":"Lightyear","middle_name":"","title":"Mr.","suffix":"","gender":"male","marital_status":"","master_person_id":30,"avatar":"http://res.cloudinary.com/cru/image/upload/c_pad,h_180,w_180/v1399573062/wxlkbf4gs9fumevf3whv.jpg","phone_number_ids":[],"email_address_ids":[29]}],"phone_numbers":[],"email_addresses":[{"id":29,"email":"buzz.lightyear@spacerangeracademy.edu","primary":true,"created_at":"2014-04-15T15:59:59.507-03:00","updated_at":"2014-04-15T15:59:59.507-03:00"}],"addresses":[{"id":40,"street":"205 10th Ave W","city":"Vancouver","state":"BC","country":"","postal_code":"V5Y 1R9","location":"","start_date":null,"end_date":null,"primary_mailing_address":false}],"contacts":[{"id":20,"name":"Lightyear, Buzz","status":"Partner - Special","likely_to_give":"Likely","church_name":"","send_newsletter":"","avatar":"http://res.cloudinary.com/cru/image/upload/c_pad,h_180,w_180/v1399573062/wxlkbf4gs9fumevf3whv.jpg","square_avatar":"http://res.cloudinary.com/cru/image/upload/c_fill,g_face,h_50,w_50/v1399573062/wxlkbf4gs9fumevf3whv.jpg","referrals_to_me_ids":[],"tag_list":[],"uncompleted_tasks_count":1,"person_ids":[59],"address_ids":[40]}],"meta":{"total":1,"from":1,"to":1,"page":1,"total_pages":1}}, {});

        //save updated view filters
        $httpBackend.when("PUT", "/api/v1/users/me").respond({}, {});

        $httpBackend.flush();

        expect($scope.totalContacts).toEqual(1);
    });
});