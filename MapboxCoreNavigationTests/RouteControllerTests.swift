import XCTest
import MapboxDirections
import Turf
@testable import MapboxCoreNavigation

class RouteControllerTests: XCTestCase {
    
    var setup: (routeController: RouteController, firstLocation: CLLocation) {
        route.accessToken = "foo"
        let navigation = RouteController(along: route, directions: directions)
        let firstCoord = navigation.routeProgress.currentLegProgress.nearbyCoordinates.first!
        return (routeController: navigation, firstLocation: CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude))
    }
    
    func testUserIsOnRoute() {
        let navigation = setup.routeController
        let firstLocation = setup.firstLocation
        
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertTrue(navigation.userIsOnRoute(firstLocation), "User should be on route")
    }
    
    func testUserIsOffRoute() {
        let navigation = setup.routeController
        let firstLocation = setup.firstLocation
        
        let coordinateOffRoute = firstLocation.coordinate.coordinate(at: 100, facing: 90)
        let locationOffRoute = CLLocation(latitude: coordinateOffRoute.latitude, longitude: coordinateOffRoute.longitude)
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [locationOffRoute])
        XCTAssertFalse(navigation.userIsOnRoute(locationOffRoute), "User should be off route")
    }
    
    func testAdvancingToFutureStepAndNotRerouting() {
        let navigation = setup.routeController
        let firstLocation = setup.firstLocation
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertTrue(navigation.userIsOnRoute(firstLocation), "User should be on route")
        XCTAssertEqual(navigation.routeProgress.currentLegProgress.stepIndex, 0, "User is on first step")
        
        let futureCoordinate = navigation.routeProgress.currentLegProgress.leg.steps[2].coordinates![10]
        let futureLocation = CLLocation(latitude: futureCoordinate.latitude, longitude: futureCoordinate.longitude)
        
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [futureLocation])
        XCTAssertTrue(navigation.userIsOnRoute(futureLocation), "User should be on route")
        
        XCTAssertEqual(navigation.routeProgress.currentLegProgress.stepIndex, 2, "User should be on route and we should increment all the way to the 4th step")
    }
    
    func testSnappedLocation() {
        let navigation = setup.routeController
        let firstLocation = setup.firstLocation
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        XCTAssertEqual(navigation.location!.coordinate, firstLocation.coordinate, "Check snapped location is working")
    }
    
    func testUserPuckShouldFaceBackwards() {
        // This route is a simple straight line: http://geojson.io/#id=gist:anonymous/64cfb27881afba26e3969d06bacc707c&map=17/37.77717/-122.46484
        let response = Fixture.JSONFromFileNamed(name: "straight-line")
        let jsonRoute = (response["routes"] as! [AnyObject]).first as! [String : Any]
        let waypoint1 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.795042, longitude: -122.413165))
        let waypoint2 = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 37.7727, longitude: -122.433378))
        let directions = Directions(accessToken: "pk.feedCafeDeadBeefBadeBede")
        let route = Route(json: jsonRoute, waypoints: [waypoint1, waypoint2], routeOptions: NavigationRouteOptions(waypoints: [waypoint1, waypoint2]))
        
        route.accessToken = "foo"
        let navigation = RouteController(along: route, directions: directions)
        let firstCoord = navigation.routeProgress.currentLegProgress.nearbyCoordinates.first!
        let firstLocation = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
        let coordNearStart = Polyline(navigation.routeProgress.currentLegProgress.nearbyCoordinates).coordinateFromStart(distance: 10)!
        
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [firstLocation])
        
        // We're now 100 meters away from the last coord, looking at the start.
        // Basically, moving backwards
        let directionToStart = coordNearStart.direction(to: firstCoord)
        let facingTowardsStartLocation = CLLocation(coordinate: coordNearStart, altitude: 0, horizontalAccuracy: 0, verticalAccuracy: 0, course: directionToStart, speed: 0, timestamp: Date())
        
        navigation.locationManager(navigation.locationManager, didUpdateLocations: [facingTowardsStartLocation])
        
        // Check the interpolated course is within reason.
        XCTAssertEqual(directionToStart, navigation.location!.course, "The course should be the raw course and not an interpolated course")
        XCTAssertFalse(facingTowardsStartLocation.shouldSnap(toRouteWith: facingTowardsStartLocation.interpolatedCourse(along: navigation.routeProgress.currentLegProgress.nearbyCoordinates)!, distanceToFirstCoordinateOnLeg: facingTowardsStartLocation.distance(from: firstLocation)), "Should not snap")
    }
}
