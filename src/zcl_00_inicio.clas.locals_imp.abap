*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

CLASS lcl_passenger_flight DEFINITION .

  PUBLIC SECTION.

    DATA carrier_id    TYPE /dmo/carrier_id       READ-ONLY.
    DATA connection_id TYPE /dmo/connection_id    READ-ONLY.
    DATA flight_date   TYPE /dmo/flight_date      READ-ONLY.

    METHODS constructor
      IMPORTING
        i_carrier_id    TYPE /dmo/carrier_id
        i_connection_id TYPE /dmo/connection_id
        i_flight_date   TYPE /dmo/flight_date.

    TYPES:
      BEGIN OF st_connection_details,
        airport_from_id TYPE /dmo/airport_from_id,
        airport_to_id   TYPE /dmo/airport_to_id,
        departure_time  TYPE /dmo/flight_departure_time,
        arrival_time    TYPE /dmo/flight_departure_time,
      END OF st_connection_details.

    TYPES
      tt_flights TYPE STANDARD TABLE OF REF TO lcl_passenger_flight WITH DEFAULT KEY.

    METHODS: get_connection_details
      RETURNING
        VALUE(r_result) TYPE st_connection_details.

    METHODS
      get_free_seats
        RETURNING
          VALUE(r_result) TYPE i.

    METHODS
      get_description RETURNING VALUE(r_result) TYPE string_table.

    CLASS-METHODS class_constructor.
    CLASS-METHODS
      get_flights_by_carrier
        IMPORTING
          i_carrier_id    TYPE /dmo/carrier_id
        RETURNING
          VALUE(r_result) TYPE tt_flights.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA planetype TYPE /dmo/plane_type_id.

    DATA seats_max  TYPE /dmo/plane_seats_max.
    DATA seats_occ  TYPE /dmo/plane_seats_occupied.
    DATA seats_free TYPE i.

    DATA price TYPE /dmo/flight_price.
    CLASS-DATA currency TYPE /dmo/currency_code VALUE 'EUR'.

    TYPES: BEGIN OF st_flights_buffer,
             carrier_id     TYPE /lrn/passflight-carrier_id,
             connection_id  TYPE /lrn/passflight-connection_id,
             flight_date    TYPE /lrn/passflight-flight_date,
             plane_type_id  TYPE /lrn/passflight-plane_type_id,
             seats_max      TYPE /lrn/passflight-seats_max,
             seats_occupied TYPE /lrn/passflight-seats_occupied,
             price          TYPE /lrn/passflight-price,
             currency_code  TYPE /lrn/passflight-currency_code,
           END OF st_flights_buffer.
    CLASS-DATA: flights_buffer TYPE TABLE OF st_flights_buffer.


    DATA connection_details TYPE st_connection_details.

    TYPES:
      BEGIN OF st_connections_buffer,
        carrier_id      TYPE /dmo/carrier_id,
        connection_id   TYPE /dmo/connection_id,
        airport_from_id TYPE /dmo/airport_from_id,
        airport_to_id   TYPE /dmo/airport_to_id,
        departure_time  TYPE /dmo/flight_departure_time,
        arrival_time    TYPE /dmo/flight_departure_time,
      END OF st_connections_buffer.

    CLASS-DATA connections_buffer TYPE TABLE OF st_connections_buffer.

ENDCLASS.

CLASS lcl_passenger_flight IMPLEMENTATION.

  METHOD class_constructor.

    SELECT
      FROM /lrn/connection
    FIELDS carrier_id, connection_id,
           airport_from_id, airport_to_id, departure_time, arrival_time
      INTO TABLE @connections_buffer.

  ENDMETHOD.

  METHOD get_flights_by_carrier.

*    SELECT
*      FROM /lrn/passflight
*    FIELDS carrier_id, connection_id, flight_date
*     WHERE carrier_id    = @i_carrier_id
*      INTO TABLE @DATA(keys).

    SELECT
      FROM /lrn/passflight
    FIELDS carrier_id, connection_id, flight_date,
           plane_type_id, seats_max, seats_occupied,
           price, currency_code
     WHERE carrier_id = @i_carrier_id
      INTO TABLE @flights_buffer.


    LOOP AT flights_buffer INTO DATA(flight).
      APPEND NEW lcl_passenger_flight( i_carrier_id    = flight-carrier_id
                                       i_connection_id = flight-connection_id
                                       i_flight_date   = flight-flight_date )
              TO r_result.
    ENDLOOP.

  ENDMETHOD.


  METHOD constructor.

    TRY.
        DATA(flight_raw) = flights_buffer[ carrier_id = i_carrier_id
                                          connection_id = i_connection_id
                                          flight_date = i_flight_date ].

      CATCH cx_sy_itab_line_not_found.
        SELECT SINGLE
          FROM /lrn/passflight
        FIELDS plane_type_id, seats_max, seats_occupied, price, currency_code
         WHERE carrier_id    = @i_carrier_id
           AND connection_id = @i_connection_id
           AND flight_date   = @i_flight_date
          INTO CORRESPONDING FIELDS OF @flight_raw .
    ENDTRY.

    IF sy-subrc = 0.
      me->carrier_id    = i_carrier_id.
      me->connection_id = i_connection_id.
      me->flight_date   = i_flight_date.

      planetype = flight_raw-plane_type_id.
      seats_max = flight_raw-seats_max.
      seats_occ = flight_raw-seats_occupied.
      seats_free = flight_raw-seats_max - flight_raw-seats_occupied.

* convert currencies
      TRY.
          cl_exchange_rates=>convert_to_local_currency(
            EXPORTING
              date              = flight_raw-flight_date
              foreign_amount    = flight_raw-price
              foreign_currency  = flight_raw-currency_code
              local_currency    = currency
            IMPORTING
              local_amount      = me->price
          ).
        CATCH cx_exchange_rates.
          CLEAR price.
      ENDTRY.

* Set connection details
*      SELECT SINGLE
*        FROM /lrn/connection
*      FIELDS airport_from_id, airport_to_id, departure_time, arrival_time
*       WHERE carrier_id    = @carrier_id
*         AND connection_id = @connection_id
*        INTO @connection_details .

      connection_details = CORRESPONDING #( connections_buffer[
                                                 carrier_id    = i_carrier_id
                                                 connection_id = i_connection_id ]
                                           ).

    ENDIF.
  ENDMETHOD.

  METHOD get_connection_details.
    r_result = me->connection_details.
  ENDMETHOD.


  METHOD get_free_seats.
    r_result = me->seats_free.
  ENDMETHOD.

  METHOD get_description.

    APPEND |Flight { carrier_id } { connection_id } on { flight_date DATE = USER } | &&
           |from { connection_details-airport_from_id } to { connection_details-airport_to_id } |
           TO r_result.
    APPEND |Planetype:      { planetype  } | TO r_result.
    APPEND |Maximum Seats:  { seats_max  } | TO r_result.
    APPEND |Occupied Seats: { seats_occ  } | TO r_result.
    APPEND |Free Seats:     { seats_free } | TO r_result.
    APPEND |Ticket Price:   { price CURRENCY = currency } { currency } | TO r_result.

  ENDMETHOD.

ENDCLASS.

CLASS lcl_cargo_flight DEFINITION .

  PUBLIC SECTION.

    TYPES: BEGIN OF st_connection_details,
             airport_from_id TYPE /dmo/airport_from_id,
             airport_to_id   TYPE /dmo/airport_to_id,
             departure_time  TYPE /dmo/flight_departure_time,
             arrival_time    TYPE /dmo/flight_departure_time,
           END OF st_connection_details.

    TYPES
       tt_flights TYPE STANDARD TABLE OF REF TO lcl_cargo_flight WITH DEFAULT KEY.

* wrong:
*    DATA carrier_id    TYPE /dmo/connection_id    READ-ONLY.
*    DATA connection_id TYPE /dmo/carrier_id       READ-ONLY.
* correct:
    DATA carrier_id    TYPE /dmo/carrier_id       READ-ONLY.
    DATA connection_id TYPE /dmo/connection_id    READ-ONLY.

    DATA flight_date   TYPE /dmo/flight_date      READ-ONLY.

    METHODS constructor
      IMPORTING
        i_carrier_id    TYPE /dmo/carrier_id
        i_connection_id TYPE /dmo/connection_id
        i_flight_date   TYPE /dmo/flight_date.

    METHODS get_connection_details
      RETURNING
        VALUE(r_result) TYPE st_connection_details.

    METHODS
      get_free_capacity
        RETURNING
          VALUE(r_result) TYPE /lrn/plane_actual_load.

    METHODS get_description
      RETURNING
        VALUE(r_result) TYPE string_table.

    CLASS-METHODS
      get_flights_by_carrier
        IMPORTING
          i_carrier_id    TYPE /dmo/carrier_id
        RETURNING
          VALUE(r_result) TYPE tt_flights.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES: BEGIN OF st_flights_buffer,
             carrier_id      TYPE /dmo/carrier_id,
             connection_id   TYPE /dmo/connection_id,
             flight_date     TYPE /dmo/flight_date,
             plane_type_id   TYPE /dmo/plane_type_id,
             maximum_load    TYPE /lrn/plane_maximum_load,
             actual_load     TYPE /lrn/plane_actual_load,
             load_unit       TYPE /lrn/plane_weight_unit,
             airport_from_id TYPE /dmo/airport_from_id,
             airport_to_id   TYPE /dmo/airport_to_id,
             departure_time  TYPE /dmo/flight_departure_time,
             arrival_time    TYPE /dmo/flight_arrival_time,
           END OF st_flights_buffer.

    TYPES tt_flights_buffer TYPE HASHED TABLE OF st_flights_buffer
                            WITH UNIQUE KEY carrier_id connection_id flight_date.

    DATA connection_details TYPE st_connection_details.

    DATA planetype TYPE /dmo/plane_type_id.

    DATA maximum_load TYPE /lrn/plane_maximum_load.
    DATA actual_load TYPE /lrn/plane_actual_load.
    DATA load_unit    TYPE /lrn/plane_weight_unit.

    CLASS-DATA flights_buffer TYPE tt_flights_buffer.

ENDCLASS.

CLASS lcl_cargo_flight IMPLEMENTATION.

  METHOD get_flights_by_carrier.

    SELECT
      FROM /lrn/cargoflight
    FIELDS carrier_id, connection_id, flight_date,
           plane_type_id, maximum_load, actual_load, load_unit,
           airport_from_id, airport_to_id, departure_time, arrival_time
     WHERE carrier_id    = @i_carrier_id
      INTO CORRESPONDING FIELDS OF TABLE @flights_buffer.

    LOOP AT flights_buffer INTO DATA(flight).
      APPEND NEW lcl_cargo_flight( i_carrier_id    = flight-carrier_id
                                   i_connection_id = flight-connection_id
                                   i_flight_date   = flight-flight_date )
              TO r_result.

    ENDLOOP.
  ENDMETHOD.

  METHOD constructor.

    " Read buffer
    TRY.
        DATA(flight_raw) = flights_buffer[ carrier_id    = i_carrier_id
                                           connection_id = i_connection_id
                                           flight_date   = i_flight_date ].

      CATCH cx_sy_itab_line_not_found.
        " Read from database if data not found in buffer
        SELECT SINGLE
          FROM /lrn/cargoflight
        FIELDS plane_type_id, maximum_load, actual_load, load_unit,
               airport_from_id, airport_to_id, departure_time, arrival_time
         WHERE carrier_id    = @i_carrier_id
           AND connection_id = @i_connection_id
           AND flight_date   = @i_flight_date
          INTO CORRESPONDING FIELDS OF @flight_raw.
    ENDTRY.

*    carrier_id    =  EXACT #( i_carrier_id ).
    carrier_id    =  i_carrier_id .
*    connection_id =  EXACT #( i_connection_id ).
    connection_id =  i_connection_id .
    flight_date   = i_flight_date.

    planetype = flight_raw-plane_type_id.
    maximum_load = flight_raw-maximum_load.
    actual_load = flight_raw-actual_load.
    load_unit = flight_raw-load_unit.

    connection_details = CORRESPONDING #( flight_raw ).

  ENDMETHOD.


  METHOD get_connection_details.
    r_result = me->connection_details.
  ENDMETHOD.


  METHOD get_free_capacity.
    r_result = maximum_load - actual_load.
  ENDMETHOD.

  METHOD get_description.

    APPEND |Flight { carrier_id } { connection_id } on { flight_date DATE = USER } | &&
           |from { connection_details-airport_from_id } to { connection_details-airport_to_id } |
           TO r_result.
    APPEND |Planetype:     { planetype } |                         TO r_result.
    APPEND |Maximum Load:  { maximum_load         } { load_unit }| TO r_result.
    APPEND |Free Capacity: { get_free_capacity( ) } { load_unit }| TO r_result.

  ENDMETHOD.

ENDCLASS.

CLASS lcl_carrier DEFINITION .

  PUBLIC SECTION.

*    TYPES t_output TYPE c LENGTH 40.
    TYPES t_output TYPE string.

    TYPES tt_output TYPE STANDARD TABLE OF t_output
                    WITH NON-UNIQUE DEFAULT KEY.

    DATA carrier_id TYPE /dmo/carrier_id READ-ONLY.

    METHODS constructor
      IMPORTING
                i_carrier_id TYPE /dmo/carrier_id
      RAISING   cx_abap_invalid_value.

    METHODS get_output RETURNING VALUE(r_result) TYPE tt_output.

    METHODS find_passenger_flight
      IMPORTING
        i_airport_from_id TYPE /dmo/airport_from_id
        i_airport_to_id   TYPE /dmo/airport_to_id
        i_from_date       TYPE /dmo/flight_date
        i_seats           TYPE i
      EXPORTING
        e_flight          TYPE REF TO lcl_passenger_flight
        e_days_later      TYPE i.

    METHODS find_cargo_flight
      IMPORTING
        i_airport_from_id TYPE /dmo/airport_from_id
        i_airport_to_id   TYPE /dmo/airport_to_id
        i_from_date       TYPE /dmo/flight_date
        i_cargo           TYPE /lrn/plane_actual_load
      EXPORTING
        e_flight          TYPE REF TO lcl_cargo_flight
        e_days_later      TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA name          TYPE string.
    DATA currency_code TYPE /dmo/currency_code ##NEEDED.

    DATA passenger_flights TYPE lcl_passenger_flight=>tt_flights.

    DATA cargo_flights TYPE lcl_cargo_flight=>tt_flights.

    METHODS get_average_free_seats
      RETURNING VALUE(r_result) TYPE i.

ENDCLASS.

CLASS lcl_carrier IMPLEMENTATION.

  METHOD constructor.

    me->carrier_id = i_carrier_id.

    SELECT SINGLE
      FROM /lrn/carrier
    FIELDS name, currency_code
     WHERE carrier_id = @i_carrier_id
     INTO ( @me->name, @me->currency_code ).

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_abap_invalid_value.
    ENDIF.

    name = carrier_id && ` ` && name.

    passenger_flights =
        lcl_passenger_flight=>get_flights_by_carrier(
              i_carrier_id    = i_carrier_id ).

    cargo_flights =
        lcl_cargo_flight=>get_flights_by_carrier(
              i_carrier_id    = i_carrier_id ).

  ENDMETHOD.

  METHOD get_output.

    APPEND |Carrier Name:       { me->name } | TO r_result.
    APPEND |Passenger Flights:  { lines( passenger_flights ) } | TO r_result.
    APPEND |Average free seats: { get_average_free_seats(  ) } | TO r_result.
    APPEND |Cargo Flights:      { lines( cargo_flights     ) } | TO r_result.

  ENDMETHOD.

  METHOD find_cargo_flight.

    e_days_later = 99999999.

    LOOP AT me->cargo_flights INTO DATA(flight)
        WHERE table_line->flight_date >= i_from_date.

      DATA(connection_details) = flight->get_connection_details(  ).

      IF connection_details-airport_from_id = i_airport_from_id
       AND connection_details-airport_to_id = i_airport_to_id
       AND flight->get_free_capacity(  ) >= i_cargo.

*        DATA(days_later) =  i_from_date - flight->flight_date.
        DATA(days_later) =   flight->flight_date - i_from_date .

        IF days_later < e_days_later. "earlier than previous one?
          e_flight = flight.
          e_days_later = days_later.
        ENDIF.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD find_passenger_flight.

    e_days_later = 99999999.

    LOOP AT me->passenger_flights INTO DATA(flight)
         WHERE table_line->flight_date >= i_from_date.

      DATA(connection_details) = flight->get_connection_details(  ).

      IF connection_details-airport_from_id = i_airport_from_id
       AND connection_details-airport_to_id = i_airport_to_id
       AND flight->get_free_seats( ) >= i_seats.
        DATA(days_later) = flight->flight_date - i_from_date.

        IF days_later < e_days_later. "earlier than previous one?
          e_flight = flight.
          e_days_later = days_later.
        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_average_free_seats.

    DATA total TYPE i.

    LOOP AT passenger_flights INTO DATA(flight).

      total = total + flight->get_free_seats( ).

    ENDLOOP.

    r_result = total / lines( passenger_flights ).

  ENDMETHOD.

ENDCLASS.
