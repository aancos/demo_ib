*"* use this source file for your ABAP unit test classes

CLASS ltcl_find_flights DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA the_carrier TYPE REF TO lcl_carrier.

    CLASS-DATA some_flight_data TYPE /lrn/cargoflight.

    CLASS-METHODS class_setup.

    METHODS:
      test_find_cargo_flight FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_find_flights IMPLEMENTATION.

  METHOD test_find_cargo_flight.

*    SELECT SINGLE
*      FROM /lrn/cargoflight
*    FIELDS carrier_id, connection_id, flight_date,
*           airport_from_id, airport_to_id
*      INTO @DATA(some_flight_data).
*
*    IF sy-subrc <> 0.
*      cl_abap_unit_assert=>fail( `No data in table /lrn/CARGOFLIGHT` ).
*    ENDIF.
*
*    TRY.
*
*        DATA(the_carrier) = NEW lcl_carrier( i_carrier_id = some_flight_data-carrier_id ).
*
*      CATCH cx_abap_invalid_value.
*
*        cl_abap_unit_assert=>fail( `Unable to instantiate lcl_carrier` ).
*
*    ENDTRY.
*
    the_carrier->find_cargo_flight(
      EXPORTING
        i_airport_from_id = some_flight_data-airport_from_id
        i_airport_to_id   = some_flight_data-airport_to_id
        i_from_date       = some_flight_data-flight_date
        i_cargo           = 1
      IMPORTING
        e_flight          = DATA(flight)
        e_days_later      = DATA(days_later)
    ).

    cl_abap_unit_assert=>assert_bound(
        act = flight
        msg = `Method find_cargo_flight does not return a result` ).

    cl_abap_unit_assert=>assert_equals(
        act = days_later
        exp = 0
        msg = `Method find_cargo_flight returns wrong result` ).


  ENDMETHOD.

  METHOD class_setup.

    SELECT SINGLE
      FROM /lrn/cargoflight
    FIELDS carrier_id, connection_id, flight_date,
           airport_from_id, airport_to_id
      INTO CORRESPONDING FIELDS OF @some_flight_data.

    IF sy-subrc <> 0.
      cl_abap_unit_assert=>fail( `No data in table /lrn/CARGOFLIGHT` ).
    ENDIF.

    TRY.

        the_carrier = NEW lcl_carrier( i_carrier_id = some_flight_data-carrier_id ).

      CATCH cx_abap_invalid_value.

        cl_abap_unit_assert=>fail( `Unable to instantiate lcl_carrier` ).

      CATCH cx_abap_auth_check_exception.

        cl_abap_unit_assert=>fail( `Unable to instantiate lcl_carrier` ).

    ENDTRY.


  ENDMETHOD.

ENDCLASS.
