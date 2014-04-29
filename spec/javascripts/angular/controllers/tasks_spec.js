describe('tasks', function() {
    beforeEach(module('mpdxApp'));
    var $scope, $location, $rootScope, createController;

    beforeEach(inject(function($injector) {
        $location = $injector.get('$location');
        $rootScope = $injector.get('$rootScope');
        $httpBackend = $injector.get('$httpBackend');
        $scope = $rootScope.$new();

        var $controller = $injector.get('$controller');

        createController = function() {
            return $controller('tasksController', {
                '$scope': $scope
            });
        };
    }));

    var task = [
        {
            account_list_id: 1,
            activity_type: "Appointment",
            comments: [],
            comments_count: 0,
            completed: false,
            completed_at: null,
            contacts: [],
            created_at: "2014-04-28T09:17:15.816-04:00",
            due_date: "2014-04-29T09:17:00.000-04:00",
            id: 1,
            person_ids: [],
            starred: false,
            subject: "Appointment with Ryan",
            tag_list: ['university'],
            updated_at: "2014-04-28T09:17:15.816-04:00"
        },
        {
            account_list_id: 1,
            activity_type: "Call",
            comments: [],
            comments_count: 0,
            completed: false,
            completed_at: null,
            contacts: [],
            created_at: "2014-04-28T09:17:15.816-04:00",
            due_date: "2014-04-29T09:17:00.000-04:00",
            id: 2,
            person_ids: [],
            starred: false,
            subject: "Call with Ryan",
            tag_list: ['church'],
            updated_at: "2014-04-28T09:17:15.816-04:00"
        }
    ];
    it('tag filter (university) should have 1 task', function() {
        var controller = createController();

        $scope.filterContactsSelect = [''];
        $scope.filterContactCitySelect = [''];
        $scope.filterContactStateSelect = [''];
        $scope.filterContactNewsletterSelect = '';
        $scope.filterContactStatusSelect = [''];
        $scope.filterContactLikelyToGiveSelect = [''];
        $scope.filterContactChurchSelect = [''];
        $scope.filterContactReferrerSelect = [''];
        $scope.filterContactTagSelect = [''];
        $scope.filterTagsSelect = ['university'];
        $scope.filterActionSelect = [''];

        expect($scope.filters(task[0])).toBe(true);
    });

    it('action filter (Appointment) should have 1 task', function() {
        var controller = createController();

        $scope.filterContactsSelect = [''];
        $scope.filterContactCitySelect = [''];
        $scope.filterContactStateSelect = [''];
        $scope.filterContactNewsletterSelect = '';
        $scope.filterContactStatusSelect = [''];
        $scope.filterContactLikelyToGiveSelect = [''];
        $scope.filterContactChurchSelect = [''];
        $scope.filterContactReferrerSelect = [''];
        $scope.filterContactTagSelect = [''];
        $scope.filterTagsSelect = [''];
        $scope.filterActionSelect = ['Appointment'];

        expect($scope.filters(task[0])).toBe(true);
    });

    it('tag should be active', function() {
        var controller = createController();

        $scope.filterTagsSelect = [''];
        $scope.tagClick('university');

        expect($scope.tagIsActive('university')).toBe(true);
    });
});


//http://sebastien.saunier.me/blog/2014/02/04/angular--rails-with-no-fuss.html