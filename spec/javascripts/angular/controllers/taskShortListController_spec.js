describe('taskShortListController', function() {
    beforeEach(module('mpdxApp'));
    var $scope, $location, $rootScope, createController;

    beforeEach(inject(function($injector) {
        $location = $injector.get('$location');
        $rootScope = $injector.get('$rootScope');
        $httpBackend = $injector.get('$httpBackend');
        $scope = $rootScope.$new();

        var $controller = $injector.get('$controller');

        createController = function() {
            return $controller('taskShortListController', {
                '$scope': $scope,
                '$http': $httpBackend
            });
        };
    }));

    it('taskShortList should return 5 tasks', function() {
        var controller = createController();
        window.current_account_list_id = 1;

        //return tasks
        $httpBackend.when("GET", /^\/api\/v1\/tasks\?.*/).respond({"comments":[],"people":[],"tasks":[{"id":239853,"account_list_id":268,"starred":false,"subject":"Another To-do","created_at":"2013-03-04T13:56:32.387-04:00","updated_at":"2013-03-04T13:56:32.387-04:00","completed":false,"completed_at":null,"activity_type":null,"tag_list":[],"contacts":[],"comments_count":0,"due_date":"2013-03-05T02:00:00.000-04:00","comments":[],"person_ids":[]},{"id":239854,"account_list_id":268,"starred":false,"subject":"Task, List Addition","created_at":"2013-03-04T13:56:52.065-04:00","updated_at":"2013-03-04T13:56:52.065-04:00","completed":false,"completed_at":null,"activity_type":null,"tag_list":[],"contacts":[],"comments_count":0,"due_date":"2013-03-06T02:00:00.000-04:00","comments":[],"person_ids":[]},{"id":239852,"account_list_id":268,"starred":false,"subject":"New Task From Mobile","created_at":"2013-03-04T13:56:09.568-04:00","updated_at":"2014-05-21T12:40:42.006-03:00","completed":false,"completed_at":null,"activity_type":"","tag_list":[],"contacts":[],"comments_count":0,"due_date":"2017-09-18T02:00:00.000-03:00","comments":[],"person_ids":[]},{"id":241010,"account_list_id":268,"starred":false,"subject":"Deer, Bambi and Feline gave a Special Gift of €73.50 on Feb 27, 2013. Send them a Thank You.","created_at":"2013-03-06T16:00:56.684-04:00","updated_at":"2013-03-06T16:00:56.684-04:00","completed":false,"completed_at":null,"activity_type":"Thank","tag_list":[],"contacts":[299714],"comments_count":0,"due_date":"2013-03-06T16:00:56.636-04:00","comments":[],"person_ids":[]},{"id":241009,"account_list_id":268,"starred":false,"subject":"Deer, Bambi and Feline gave a Special Gift of €73.50 on Feb 27, 2013. Send them a Thank You.","created_at":"2013-03-06T16:00:56.565-04:00","updated_at":"2014-05-22T10:56:19.449-03:00","completed":false,"completed_at":null,"activity_type":"Thank","tag_list":[],"contacts":[299737],"comments_count":0,"due_date":"2014-05-22T16:00:00.000-03:00","comments":[],"person_ids":[]}],"meta":{"total":73,"from":1,"to":5,"page":1,"total_pages":15}});

        //return contact
        $httpBackend.when("GET", /^\/api\/v1\/contacts\?.*/).respond({"people":[{"id":59,"first_name":"Buzz","last_name":"Lightyear","middle_name":"","title":"Mr.","suffix":"","gender":"male","marital_status":"","master_person_id":30,"avatar":"http://res.cloudinary.com/cru/image/upload/c_pad,h_180,w_180/v1399573062/wxlkbf4gs9fumevf3whv.jpg","phone_number_ids":[],"email_address_ids":[29]}],"phone_numbers":[],"email_addresses":[{"id":29,"email":"buzz.lightyear@spacerangeracademy.edu","primary":true,"created_at":"2014-04-15T15:59:59.507-03:00","updated_at":"2014-04-15T15:59:59.507-03:00"}],"addresses":[{"id":40,"street":"205 10th Ave W","city":"Vancouver","state":"BC","country":"","postal_code":"V5Y 1R9","location":"","start_date":null,"end_date":null,"primary_mailing_address":false}],"contacts":[{"id":20,"name":"Lightyear, Buzz","status":"Partner - Special","likely_to_give":"Likely","church_name":"","send_newsletter":"","avatar":"http://res.cloudinary.com/cru/image/upload/c_pad,h_180,w_180/v1399573062/wxlkbf4gs9fumevf3whv.jpg","square_avatar":"http://res.cloudinary.com/cru/image/upload/c_fill,g_face,h_50,w_50/v1399573062/wxlkbf4gs9fumevf3whv.jpg","referrals_to_me_ids":[],"tag_list":[],"uncompleted_tasks_count":1,"person_ids":[59],"address_ids":[40]}],"meta":{"total":1,"from":1,"to":1,"page":1,"total_pages":1}}, {});


        $scope.init();
        $httpBackend.flush();

        expect($scope.tasks.length).toBe(5);
    });
});