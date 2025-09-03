*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type
*"* declarations

INTERFACE lif_output.
  TYPES t_output TYPE string.
  TYPES tt_output TYPE STANDARD TABLE OF t_output
                  WITH NON-UNIQUE DEFAULT KEY.
  METHODS get_output RETURNING VALUE(r_result) TYPE tt_output.

ENDINTERFACE.

CLASS lcl_flight DEFINITION ABSTRACT.

  PUBLIC SECTION.

    INTERFACES lif_output.

    ALIASES get_output FOR lif_output~get_output.

    METHODS constructor
      IMPORTING
        i_carrier_id    TYPE /dmo/carrier_id
        i_connection_id TYPE /dmo/connection_id
        i_flight_date   TYPE /dmo/flight_date.

    TYPES tab TYPE STANDARD TABLE OF REF TO lcl_flight WITH DEFAULT KEY.

    TYPES: BEGIN OF st_connection_details,
             airport_from_id TYPE /dmo/airport_from_id,
             airport_to_id   TYPE /dmo/airport_to_id,
             departure_time  TYPE /dmo/flight_departure_time,
             arrival_time    TYPE /dmo/flight_departure_time,
             duration        TYPE i,
           END OF st_connection_details.

    DATA carrier_id    TYPE /dmo/carrier_id       READ-ONLY.
    DATA connection_id TYPE /dmo/connection_id    READ-ONLY.
    DATA flight_date   TYPE /dmo/flight_date      READ-ONLY.

    METHODS: get_connection_details
      RETURNING
        VALUE(r_result) TYPE st_connection_details.

  PROTECTED SECTION.

    DATA planetype TYPE /dmo/plane_type_id.
    DATA connection_details TYPE st_connection_details.
    METHODS get_description
      RETURNING
        VALUE(r_result) TYPE string_table.

  PRIVATE SECTION.

ENDCLASS.

CLASS lcl_flight IMPLEMENTATION.

  METHOD get_connection_details.
    r_result = me->connection_details.
  ENDMETHOD.

  METHOD get_description.

    DATA txt TYPE string.

    txt = 'Flight &carrid& &connid& on &date& from &from& to &to&'(005).
    txt = replace( val = txt sub = '&carrid&' with = carrier_id ).
    txt = replace( val = txt sub = '&connid&' with = connection_id ).
    txt = replace( val = txt sub = '&date&'   with = |{ flight_date DATE = USER }| ).
    txt = replace( val = txt sub = '&from&' with = connection_details-airport_from_id ).
    txt = replace( val = txt sub = '&to&'   with = connection_details-airport_to_id ).
    APPEND txt TO r_result.

    APPEND |{ 'Planetype:'(006)      } { planetype  } | TO r_result.

  ENDMETHOD.

  METHOD constructor.
    me->carrier_id    = i_carrier_id.
    me->connection_id = i_connection_id.
    me->flight_date   = i_flight_date.
  ENDMETHOD.

  METHOD lif_output~get_output.
    r_result = get_description( ).
  ENDMETHOD.

ENDCLASS.

CLASS lcl_passenger_flight DEFINITION
            INHERITING FROM lcl_flight.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        i_carrier_id    TYPE /dmo/carrier_id
        i_connection_id TYPE /dmo/connection_id
        i_flight_date   TYPE /dmo/flight_date.

    TYPES
      tt_flights TYPE STANDARD TABLE OF REF TO lcl_passenger_flight WITH DEFAULT KEY.

    METHODS
      get_free_seats
        RETURNING
          VALUE(r_result) TYPE i.

    CLASS-METHODS class_constructor.
    CLASS-METHODS
      get_flights_by_carrier
        IMPORTING
          i_carrier_id    TYPE /dmo/carrier_id
        RETURNING
          VALUE(r_result) TYPE tt_flights.

  PROTECTED SECTION.

    METHODS
      get_description REDEFINITION.

  PRIVATE SECTION.

    DATA seats_max  TYPE /dmo/plane_seats_max.
    DATA seats_occ  TYPE /dmo/plane_seats_occupied.


    DATA price TYPE /dmo/flight_price.
    CLASS-DATA currency TYPE /dmo/currency_code VALUE 'EUR'.

    TYPES: BEGIN OF st_flights_buffer,
             carrier_id     TYPE /lrn/passflight-carrier_id,
             connection_id  TYPE /lrn/passflight-connection_id,
             flight_date    TYPE /lrn/passflight-flight_date,
             plane_type_id  TYPE /lrn/passflight-plane_type_id,
             seats_max      TYPE /lrn/passflight-seats_max,
             seats_occupied TYPE /lrn/passflight-seats_occupied,
             seats_free     TYPE i,
             price          TYPE /lrn/passflight-price,
             currency_code  TYPE /lrn/passflight-currency_code,
           END OF st_flights_buffer.

    CLASS-DATA: flights_buffer
          TYPE HASHED TABLE OF st_flights_buffer
          WITH UNIQUE KEY carrier_id connection_id flight_date
          WITH NON-UNIQUE SORTED KEY sk_carrier COMPONENTS carrier_id.

    DATA seats_free TYPE i.

    TYPES:
      BEGIN OF st_connections_buffer,
        carrier_id      TYPE /dmo/carrier_id,
        connection_id   TYPE /dmo/connection_id,
        airport_from_id TYPE /dmo/airport_from_id,
        airport_to_id   TYPE /dmo/airport_to_id,
        departure_time  TYPE /dmo/flight_departure_time,
        arrival_time    TYPE /dmo/flight_departure_time,
        timzone_from    TYPE timezone,
        timzone_to      TYPE timezone,
        duration        TYPE i,
      END OF st_connections_buffer.

    CLASS-DATA connections_buffer
          TYPE HASHED TABLE OF st_connections_buffer
          WITH UNIQUE KEY carrier_id connection_id.

ENDCLASS.

CLASS lcl_passenger_flight IMPLEMENTATION.

  METHOD class_constructor.

    DATA(today) = cl_abap_context_info=>get_system_date( ).

    SELECT
      FROM /lrn/connection AS c
      LEFT OUTER JOIN /lrn/airport AS f
        ON c~airport_from_id = f~airport_id
      LEFT OUTER JOIN /lrn/airport AS t
        ON c~airport_to_id = t~airport_id
    FIELDS carrier_id, connection_id,
           airport_from_id, airport_to_id, departure_time, arrival_time,
           f~timzone AS timezone_from,
           t~timzone AS timezone_to,
           div(
                tstmp_seconds_between(
                  tstmp1 = dats_tims_to_tstmp(
                             date = @today,
                             time = c~departure_time,
                             tzone = f~timzone ),
                  tstmp2 = dats_tims_to_tstmp(
                             date = @today,
                             time = c~arrival_time,
                             tzone = t~timzone )
                                            ),
                60 )
      INTO TABLE @connections_buffer.

  ENDMETHOD.

  METHOD get_flights_by_carrier.

    IF NOT line_exists(  flights_buffer[
                                 KEY sk_carrier
                          COMPONENTS carrier_id = i_carrier_id
                         ]
                       ).
      SELECT
        FROM /lrn/passflight
      FIELDS carrier_id, connection_id, flight_date,
             plane_type_id, seats_max, seats_occupied,
             seats_max - seats_occupied AS seats_free,
             currency_conversion(
               amount             = price,
               source_currency    = currency_code,
               target_currency    = @currency,
               exchange_rate_date = flight_date,
               on_error           = @sql_currency_conversion=>c_on_error-set_to_null
                                ) AS price,
            @currency AS currency_code
      WHERE carrier_id = @i_carrier_id
      APPENDING TABLE @flights_buffer.

    ENDIF.

    r_result = VALUE #(
                  FOR <flight> IN flights_buffer
                  USING KEY sk_carrier
                  WHERE ( carrier_id = i_carrier_id )
                  ( NEW lcl_passenger_flight(
                         i_carrier_id    = <flight>-carrier_id
                         i_connection_id = <flight>-connection_id
                         i_flight_date   = <flight>-flight_date
                    )
                  )
               ).

  ENDMETHOD.

  METHOD constructor.

    super->constructor(
      i_carrier_id    = i_carrier_id
      i_connection_id = i_connection_id
      i_flight_date   = i_flight_date
    ).

    TRY.
        DATA(flight_raw) = flights_buffer[ carrier_id    = i_carrier_id
                                           connection_id = i_connection_id
                                           flight_date   = i_flight_date ].

      CATCH cx_sy_itab_line_not_found.
        SELECT SINGLE
          FROM /lrn/passflight
        FIELDS plane_type_id,
               seats_max, seats_occupied,
               seats_max - seats_occupied AS seats_free,
*               price,
               currency_conversion(
                 amount             = price,
                 source_currency    = currency_code,
                 target_currency    = @currency,
                 exchange_rate_date = flight_date
*                 ,
*                 on_error           = @sql_currency_conversion=>c_on_error-set_to_null
                                  ) AS price,
               @currency AS currency_code
         WHERE carrier_id    = @i_carrier_id
           AND connection_id = @i_connection_id
           AND flight_date   = @i_flight_date
          INTO CORRESPONDING FIELDS OF @flight_raw .
    ENDTRY.

    IF sy-subrc = 0.

      planetype = flight_raw-plane_type_id.
      seats_max = flight_raw-seats_max.
      seats_occ = flight_raw-seats_occupied.
      seats_free = flight_raw-seats_free.

* Set connection details

      connection_details = CORRESPONDING #( connections_buffer[
                                                 carrier_id    = i_carrier_id
                                                 connection_id = i_connection_id ]
                                           ).

    ENDIF.
  ENDMETHOD.




  METHOD get_free_seats.
    r_result = me->seats_free.
  ENDMETHOD.

  METHOD get_description.

    r_result = super->get_description(  ).

    APPEND |{ 'Maximum Seats:'(007)  } { seats_max  } | TO r_result.
    APPEND |{ 'Occupied Seats:'(008) } { seats_occ  } | TO r_result.
    APPEND |{ 'Free Seats:'(009)     } { seats_free } | TO r_result.
    APPEND |{ 'Ticket Price:'(010)   } { price CURRENCY = currency } { currency } | TO r_result.

    APPEND |{ 'Duration:'(011)       } { connection_details-duration } { 'minutes'(012) }| TO r_result.

  ENDMETHOD.

ENDCLASS.

CLASS lcl_cargo_flight DEFINITION INHERITING FROM lcl_flight.

  PUBLIC SECTION.

    TYPES
       tt_flights TYPE STANDARD TABLE OF REF TO lcl_cargo_flight WITH DEFAULT KEY.

    METHODS constructor
      IMPORTING
        i_carrier_id    TYPE /dmo/carrier_id
        i_connection_id TYPE /dmo/connection_id
        i_flight_date   TYPE /dmo/flight_date.

    METHODS
      get_free_capacity
        RETURNING
          VALUE(r_result) TYPE /lrn/plane_actual_load.

    CLASS-METHODS
      get_flights_by_carrier
        IMPORTING
          i_carrier_id    TYPE /dmo/carrier_id
        RETURNING
          VALUE(r_result) TYPE tt_flights.

  PROTECTED SECTION.

    METHODS get_description REDEFINITION.

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

    super->constructor(
      i_carrier_id    = i_carrier_id
      i_connection_id = i_connection_id
      i_flight_date   = i_flight_date
    ).

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

    planetype = flight_raw-plane_type_id.
    maximum_load = flight_raw-maximum_load.
    actual_load = flight_raw-actual_load.
    load_unit = flight_raw-load_unit.

    connection_details = CORRESPONDING #( flight_raw ).

    connection_details-duration = ( connection_details-arrival_time
                                  - connection_details-departure_time )
                                  / 60.

  ENDMETHOD.

  METHOD get_free_capacity.
    r_result = maximum_load - actual_load.
  ENDMETHOD.

  METHOD get_description.

    r_result = super->get_description( ).

    APPEND |Maximum Load:  { maximum_load         } { load_unit }| TO r_result.
    APPEND |Free Capacity: { get_free_capacity( ) } { load_unit }| TO r_result.

  ENDMETHOD.

ENDCLASS.

CLASS lcl_carrier DEFINITION CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES lif_output.
    ALIASES: get_output FOR lif_output~get_output,
             tt_output FOR lif_output~tt_output,
             t_output FOR lif_output~t_output.

    TYPES: tt_carriers TYPE STANDARD TABLE OF
                        REF TO lcl_carrier
                       WITH DEFAULT KEY.

    "!  vdgcxgfgfd
    "! @parameter i_carrier_id | gfgfdg
    "! @parameter r_result | dgfdgffd
    "! @raising /lrn/cx_s4d401_exs_failed |
    CLASS-METHODS get_instance
      IMPORTING
        i_carrier_id    TYPE /dmo/carrier_id
      RETURNING
        VALUE(r_result) TYPE REF TO lcl_carrier
      RAISING
*        cx_abap_invalid_value
*        cx_abap_auth_check_exception
       /lrn/cx_s4d401_exs_failed.


    DATA carrier_id TYPE /dmo/carrier_id READ-ONLY.

    "!
    "! @parameter i_carrier_id | faefasr
    METHODS constructor
      IMPORTING
                i_carrier_id TYPE /dmo/carrier_id.

    METHODS find_passenger_flight
      IMPORTING
        i_airport_from_id TYPE /dmo/airport_from_id
        i_airport_to_id   TYPE /dmo/airport_to_id
        i_from_date       TYPE /dmo/flight_date
        i_seats           TYPE i
      EXPORTING
        e_flight          TYPE REF TO lcl_flight
        e_days_later      TYPE i.

    METHODS find_cargo_flight
      IMPORTING
        i_airport_from_id TYPE /dmo/airport_from_id
        i_airport_to_id   TYPE /dmo/airport_to_id
        i_from_date       TYPE /dmo/flight_date
        i_cargo           TYPE /lrn/plane_actual_load
      EXPORTING
*        e_flight          TYPE REF TO lcl_cargo_flight
        e_flight          TYPE REF TO lcl_flight
        e_days_later      TYPE i.

  PROTECTED SECTION.

  PRIVATE SECTION.

    CLASS-DATA instances TYPE tt_carriers.

    DATA name          TYPE string.
    DATA currency_code TYPE /dmo/currency_code ##NEEDED.

    DATA flights           TYPE lcl_flight=>tab.

    DATA pf_count TYPE i.
    DATA cf_count TYPE i.

    METHODS get_average_free_seats
      RETURNING VALUE(r_result) TYPE i.

ENDCLASS.

CLASS lcl_carrier IMPLEMENTATION.

  METHOD get_instance.

    SELECT SINGLE
      FROM /lrn/carrier
    FIELDS concat_with_space( carrier_id, name, 1 ) AS name,
           currency_code
     WHERE carrier_id = @i_carrier_id
     INTO @DATA(details).

    IF sy-subrc <> 0.
*      RAISE EXCEPTION TYPE cx_abap_invalid_value
*        EXPORTING
*          value = CONV #( i_carrier_id ).
   .
      RAISE EXCEPTION TYPE /lrn/cx_s4d401_exs_failed
        EXPORTING
          textid     = /lrn/cx_s4d401_exs_failed=>carrier_not_exist

          carrier_id = i_carrier_id.
    ENDIF.

    AUTHORITY-CHECK
           OBJECT '/LRN/CARR'
               ID '/LRN/CARR' FIELD i_carrier_id
               ID 'ACTVT'     FIELD '03'.

    IF sy-subrc <> 0.
*      RAISE EXCEPTION TYPE cx_abap_auth_check_exception
*        EXPORTING
*          textid = cx_abap_auth_check_exception=>missing_authorization.
      RAISE EXCEPTION TYPE /lrn/cx_s4d401_exs_failed
        EXPORTING
          textid     = /lrn/cx_s4d401_exs_failed=>carrier_no_read_auth
*         previous   =
          carrier_id = i_carrier_id.
    ENDIF.

    TRY.
        r_result = instances[ table_line->carrier_id = i_carrier_id  ].

      CATCH cx_sy_itab_line_not_found.

        r_result = NEW #(
                     i_carrier_id = i_carrier_id
                   ).
        r_result->name          = details-name.
        r_result->currency_code = details-currency_code.

        APPEND r_result TO instances.

    ENDTRY.

  ENDMETHOD.

  METHOD constructor.

    me->carrier_id = i_carrier_id.

    DATA(passenger_flights) =
        lcl_passenger_flight=>get_flights_by_carrier(
              i_carrier_id    = i_carrier_id ).

    pf_count = lines(  passenger_flights ).

    DATA(cargo_flights) =
        lcl_cargo_flight=>get_flights_by_carrier(
              i_carrier_id    = i_carrier_id ).

    cf_count = lines(  cargo_flights     ).


    LOOP AT passenger_flights INTO DATA(passflight).
      APPEND passflight TO flights.
    ENDLOOP.

    LOOP AT cargo_flights INTO DATA(cargoflight).
      APPEND cargoflight TO flights.
    ENDLOOP.

** Alternative: table comprehensions
*    flights = VALUE #( BASE flights
*                       FOR pflight IN passenger_flights
*                      ( pflight )
*              ).
*
*    flights = VALUE #( BASE flights
*                       FOR cflight IN cargo_flights
*                      ( cflight )
*              ).

  ENDMETHOD.

  METHOD lif_output~get_output.

    APPEND |{ 'Carrier Name:'(001)       } { me->name } | TO r_result.
    APPEND |{ 'Passenger Flights:'(002)  } { pf_count } | TO r_result.
    APPEND |{ 'Average free seats:'(003) } { get_average_free_seats(  ) } | TO r_result.
    APPEND |{ 'Cargo Flights:'(004)      } { cf_count } | TO r_result.

  ENDMETHOD.

  METHOD find_cargo_flight.

    e_days_later = 99999999.

*    LOOP AT me->cargo_flights INTO DATA(flight)
    LOOP AT me->flights INTO DATA(flight)
        WHERE table_line->flight_date >= i_from_date
        AND table_line IS INSTANCE OF lcl_cargo_flight.

      DATA(connection_details) = flight->get_connection_details(  ).

      IF connection_details-airport_from_id = i_airport_from_id
       AND connection_details-airport_to_id = i_airport_to_id
*       AND flight->get_free_capacity(  ) >= i_cargo.
       AND CAST lcl_cargo_flight( flight )->get_free_capacity(  ) >= i_cargo.

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

    LOOP AT me->flights INTO DATA(flight)
         WHERE table_line->flight_date >= i_from_date
          AND table_line IS INSTANCE OF lcl_passenger_flight.

      DATA(connection_details) = flight->get_connection_details(  ).

      IF connection_details-airport_from_id = i_airport_from_id
       AND connection_details-airport_to_id = i_airport_to_id
       AND CAST lcl_passenger_flight( flight )->get_free_seats( )
           >= i_seats.
        DATA(days_later) = flight->flight_date - i_from_date.

        IF days_later < e_days_later. "earlier than previous one?
          e_flight = flight.
          e_days_later = days_later.
        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_average_free_seats.

* Table Reductions
**********************************************************************
    r_result =
      REDUCE #(
        INIT i = 0
         FOR <flight> IN flights
       WHERE ( table_line IS INSTANCE OF lcl_passenger_flight )
        NEXT i += CAST lcl_passenger_flight( <flight> )->get_free_seats( )
      )
      / pf_count .

  ENDMETHOD.

ENDCLASS.
