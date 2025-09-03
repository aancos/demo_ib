CLASS zcx_00_failed DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_t100_message .
    INTERFACES if_t100_dyn_msg .

    constants:
      begin of carrier_not_exist,
        msgid type symsgid value 'Z00_MESSAGES',
        msgno type symsgno value '010',
        attr1 type scx_attrname value 'carrier_id',
        attr2 type scx_attrname value 'attr2',
        attr3 type scx_attrname value 'attr3',
        attr4 type scx_attrname value 'attr4',
      end of carrier_not_exist.


    constants:
      begin of carrier_no_read_auth,
        msgid type symsgid value 'Z00_MESSAGES',
        msgno type symsgno value '010',
        attr1 type scx_attrname value 'carrier_id',
        attr2 type scx_attrname value 'attr2',
        attr3 type scx_attrname value 'attr3',
        attr4 type scx_attrname value 'attr4',
      end of carrier_no_read_auth.

data: carrier_id type /lrn/carrier-carrier_id.

    METHODS constructor
      IMPORTING
        !textid   LIKE if_t100_message=>t100key OPTIONAL
        !previous LIKE previous OPTIONAL
        carrier_id LIKE carrier_id OPTIONAL.


  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_00_failed IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.
    super->constructor(
    previous = previous
    ).
    CLEAR me->textid.
*    IF textid IS INITIAL.
*      if_t100_message~t100key = if_t100_message=>default_textid.
*    ELSE.
*      if_t100_message~t100key = textid.
*    ENDIF.


        IF textid IS INITIAL.
        if_t100_message~t100key = if_t100_message=>default_textid.
        ELSE.if_t100_message~t100key = textid.
        ENDIF.
        IF carrier_id IS NOT INITIAL.
        me->carrier_id = carrier_id.
        ENDIF.
  ENDMETHOD.
ENDCLASS.
