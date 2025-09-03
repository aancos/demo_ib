CLASS zcl_00_final DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_00_FINAL IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    CONSTANTS c_carrier_id TYPE /dmo/carrier_id VALUE 'LH'.
*    CONSTANTS c_carrier_id TYPE /dmo/carrier_id VALUE 'XX'.
*    CONSTANTS c_carrier_id TYPE /dmo/carrier_id VALUE 'UA'.

    TRY.
        DATA(carrier)  = lcl_carrier=>get_instance(  i_carrier_id = c_carrier_id ).

        out->write(  name = `Carrier Overview`
                     data = carrier->get_output(  ) ).

*      CATCH cx_abap_invalid_value INTO DATA(exc_val).
*        out->write( exc_val->get_text( ) ).
*      CATCH cx_abap_auth_check_exception INTO DATA(exc_auth).
*        out->write( exc_auth->get_text( ) ).
      CATCH /lrn/cx_s4d401_exs_failed INTO DATA(exc_fail).
        out->write(  exc_fail->get_text( ) ).
    ENDTRY.

    IF carrier IS BOUND.

      out->write(  `--------------------------------------------------` ).

* Find a passenger flight from Frankfurt to New York
* starting as soon as possible after tomorrow
* with at least 5 free seats

      DATA(today) = cl_abap_context_info=>get_system_date(  ).

      carrier->find_passenger_flight(
         EXPORTING
           i_airport_from_id = 'FRA'
           i_airport_to_id   = 'JFK'
           i_from_date       = today
           i_seats           = 5
         IMPORTING
           e_flight =     DATA(pass_flight)
           e_days_later = DATA(days_later)
                         ).

      IF pass_flight IS BOUND.
        out->write( name = |Found a suitable passenger flight in { days_later } days:|
                    data = pass_flight->get_output( ) ).
      ELSE.
        out->write( data = `No Passenger Flight found` ).
      ENDIF.

      out->write(  `--------------------------------------------------` ).

** Find a cargo flight from Frankfurt to New York
** starting as soon as possible but earliest in 7 days
** with at least 1200 KG free capacity
*
      carrier->find_cargo_flight(
         EXPORTING
           i_airport_from_id = 'FRA'
           i_airport_to_id   = 'JFK'
           i_from_date       = today
           i_cargo           = 1200
         IMPORTING
           e_flight =     DATA(cargo_flight)
           e_days_later = DATA(days_later2)
                         ).

      IF cargo_flight IS BOUND.
        out->write( name = |Found a suitable cargo flight in { days_later2 } days:|
                    data = cargo_flight->get_output( ) ).
      ELSE.
        out->write( data = `No cargo flight found` ).
      ENDIF.



    ENDIF.

  ENDMETHOD.
ENDCLASS.
