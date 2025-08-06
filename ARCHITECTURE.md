# Pokemon VGC Stats - Backend Refactoring

## Architecture Overview

This application has been refactored to move statistical calculations from JavaScript to the Rails backend, implementing a proper MVC pattern with view models and services.

## New Architecture Components

### View Models

1. **PokemonStatsViewModel** (`app/models/pokemon_stats_view_model.rb`)
   - Represents the overall stats data for a month/format combination
   - Contains pokemon data, usage charts data, and pokemon list
   - Handles caching and validation

2. **PokemonDetailsViewModel** (`app/models/pokemon_details_view_model.rb`)
   - Represents detailed statistics for a specific Pokemon
   - Contains items, moves, abilities, natures, and stat distributions
   - Includes metadata like usage percentage and raw count

3. **UsageChartsViewModel** (`app/models/usage_charts_view_model.rb`)
   - Represents chart data for usage statistics
   - Handles regular Pokemon, restricted Pokemon, and restricted pairs
   - Provides formatted data for charts

### Services

1. **SmogonDataService** (`app/services/smogon_data_service.rb`)
   - Handles all external API calls to Smogon
   - Fetches months, formats, and chaos data
   - Centralized error handling for external requests

2. **PokemonStatsCalculationService** (`app/services/pokemon_stats_calculation_service.rb`)
   - Performs all statistical calculations previously done in JavaScript
   - Calculates usage charts, stat distributions, and Pokemon details
   - Uses base stats from Pokedex for accurate calculations

3. **PokemonStatsService** (`app/services/pokemon_stats_service.rb`)
   - Main service layer that coordinates data fetching and calculations
   - Handles caching for improved performance
   - Orchestrates view model creation and population

### Controller Changes

The `StatsController` has been simplified and now:
- Uses dependency injection for the main service
- Handles errors gracefully with proper HTTP status codes
- Returns structured JSON data with pre-calculated results
- Implements proper separation of concerns

### Frontend Changes

The JavaScript has been simplified to:
- Use backend-calculated data instead of performing calculations
- Render charts and lists from structured data
- Remove duplicate calculation logic
- Focus on presentation rather than computation

## Benefits of the New Architecture

1. **Performance**: Server-side calculations are faster and more efficient
2. **Maintainability**: Single source of truth for calculation logic
3. **Caching**: Backend caching reduces API calls and improves response times
4. **Testability**: Business logic can be properly unit tested
5. **Scalability**: Calculations can be optimized and scaled on the server
6. **Consistency**: Ensures calculations are consistent across all requests

## Caching Strategy

- Pokemon stats data cached for 1 hour
- Months and formats cached for 6 hours
- Individual Pokemon details cached for 1 hour
- Uses Rails.cache (memory store in development, can be configured for production)

## API Endpoints

- `GET /months` - Returns available months
- `GET /formats?month=YYYY-MM` - Returns available formats for a month
- `GET /data?month=YYYY-MM&format=FORMAT` - Returns complete stats data with calculations
- `GET /pokemon_details?month=YYYY-MM&format=FORMAT&name=POKEMON` - Returns detailed Pokemon stats

## Dependencies

- `httparty` - For external API calls
- `nokogiri` - For HTML parsing
- Rails built-in caching
- ActiveModel for view model attributes and validations

## Running the Application

```bash
bundle install
rails server
```

The application will be available at `http://localhost:3000`

## Testing

To test the new architecture:

1. Load the application in your browser
2. Select a month and format
3. Click "Load Data" to see the backend-calculated charts
4. Click on any Pokemon to see detailed stats calculated server-side
5. Check the browser network tab to see the optimized API responses

All statistical calculations are now performed on the server, with the frontend focusing purely on data presentation.
