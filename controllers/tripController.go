package controllers

import (
	"FlutterBackend/initializers"
	"FlutterBackend/models"
	"FlutterBackend/services"
	"net/http"
	"net/url"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/sirupsen/logrus"
)

/* Driver */

func GetPlannedTripsForDriver(c *gin.Context) {
	driverID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User ID not found in context"})
		return
	}

	var trips []models.Trip
	if err := initializers.DB.Where("driver_id = ? AND departure_time > ?", driverID.(uint), time.Now()).
		Preload("StartLocation").
		Preload("EndLocation").
		Find(&trips).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch planned trips"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"trips": trips})
}

const customTimeLayout = "02.01.2006 15:04"

func CreateTrip(c *gin.Context) {
	driverID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User ID not found in context"})
		return
	}

	var driver models.User
	if err := initializers.DB.First(&driver, driverID).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Unauthorized: Invalid driver ID"})
		return
	}

	var vehicle models.Vehicle
	if err := initializers.DB.Where("driver_id = ?", driverID).First(&vehicle).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Driver must add a vehicle before planning a trip"})
		return
	}

	var input struct {
		// Locations
		StartLatitude  float64 `json:"start_latitude" binding:"required"`
		StartLongitude float64 `json:"start_longitude" binding:"required"`
		EndLatitude    float64 `json:"end_latitude" binding:"required"`
		EndLongitude   float64 `json:"end_longitude" binding:"required"`
		// Info
		DepartureTime string  `json:"departure_time" binding:"required"`
		TotalSeats    int     `json:"total_seats" binding:"required,min=1"`
		PricePerSeat  float64 `json:"price_per_seat" binding:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		logrus.Warn("ERROR BINDING: %s", err.Error())
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	departureTime, err := time.Parse(customTimeLayout, input.DepartureTime)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid departure time format. Use 'DD.MM.YYYY HH:MM'"})
		return
	}

	startLocation, err := services.FindOrCreateLocation(input.StartLatitude, input.StartLongitude)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to find or create start location:", "Info": err.Error()})
		return
	}

	endLocation, err := services.FindOrCreateLocation(input.EndLatitude, input.EndLongitude)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to find or create end location"})
		return
	}

	trip := models.Trip{
		DriverID:        driver.UserID,
		StartLocationID: startLocation.LocationID,
		EndLocationID:   endLocation.LocationID,
		DepartureTime:   departureTime,
		TotalSeats:      input.TotalSeats,
		AvailableSeats:  input.TotalSeats,
		PricePerSeat:    input.PricePerSeat,
	}

	if err := initializers.DB.Create(&trip).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create trip"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"message": "Trip created successfully", "trip": trip})
}

/* Fellow Traveller */

func SearchTrips(c *gin.Context) {
	startCityEncoded := c.Query("start_city")
	endCityEncoded := c.Query("end_city")

	startCity, _ := url.QueryUnescape(startCityEncoded)
	endCity, _ := url.QueryUnescape(endCityEncoded)

	if startCity == "" || endCity == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Start city and end city are required"})
		return
	}

	var trips []models.Trip
	query := initializers.DB.Model(&models.Trip{}).
		Joins("JOIN locations AS start_location ON trips.start_location_id = start_location.location_id").
		Joins("JOIN locations AS end_location ON trips.end_location_id = end_location.location_id").
		Where("start_location.city = ? AND end_location.city = ?", startCity, endCity).
		Preload("Driver").
		Preload("StartLocation").
		Preload("EndLocation")

	if err := query.Find(&trips).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search trips"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"trips": trips})
}