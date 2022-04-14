CREATE OR REPLACE TRIGGER C_INT_CONSUMER_CARTEIRA_TRG
   FOR INSERT OR UPDATE OR DELETE ON C_CUSTUMERS_PORT_TAB
   COMPOUND TRIGGER
      -- local variables here
      msg_erro_       VARCHAR2(2000);
      linha       NUMBER;

      TYPE rec_type IS RECORD (codigoCliente_New_ C_CUSTUMERS_PORT_TAB.CUSTOMER_ID%TYPE,
                               codigoCliente_Old_ C_CUSTUMERS_PORT_TAB.CUSTOMER_ID%TYPE,
                               codigoVendedor_New_ C_CUSTUMERS_PORT_TAB.VENDOR_ID%TYPE,
                               codigoVendedor_Old_ C_CUSTUMERS_PORT_TAB.VENDOR_ID%TYPE,
                               carteiraPadrao_New_ C_CUSTUMERS_PORT_TAB.PORTFOLIO_DEFAULT%TYPE,
                               carteiraPadrao_Old_ C_CUSTUMERS_PORT_TAB.PORTFOLIO_DEFAULT%TYPE,
                               operacao_ VARCHAR2(1)
                               );
      TYPE table_type IS TABLE OF rec_type;
      tabRegistro table_type := table_type();

      AFTER EACH ROW IS
         BEGIN
            tabRegistro.EXTEND;
            linha := tabRegistro.LAST();

            CASE WHEN INSERTING THEN
                     tabRegistro(linha).codigoCliente_New_  := :NEW.CUSTOMER_ID;
                     tabRegistro(linha).codigoVendedor_New_ := :NEW.VENDOR_ID;
                     tabRegistro(linha).carteiraPadrao_New_ := :NEW.PORTFOLIO_DEFAULT;
                     tabRegistro(linha).operacao_           := 'I';

                 WHEN UPDATING THEN
                     tabRegistro(linha).codigoCliente_New_  := :NEW.CUSTOMER_ID;
                     tabRegistro(linha).codigoCliente_Old_  := :OLD.CUSTOMER_ID;
                     tabRegistro(linha).codigoVendedor_New_ := :NEW.VENDOR_ID;
                     tabRegistro(linha).carteiraPadrao_New_ := :NEW.PORTFOLIO_DEFAULT;
                     tabRegistro(linha).carteiraPadrao_Old_ := :OLD.PORTFOLIO_DEFAULT;
                     tabRegistro(linha).operacao_           := 'U';

                  WHEN DELETING THEN
                      tabRegistro(linha).codigoCliente_Old_  := :OLD.CUSTOMER_ID;
                      tabRegistro(linha).codigoCliente_Old_  := :OLD.CUSTOMER_ID;
                      tabRegistro(linha).codigoVendedor_Old_ := :OLD.VENDOR_ID;
                      tabRegistro(linha).carteiraPadrao_Old_ := :OLD.PORTFOLIO_DEFAULT;
                      tabRegistro(linha).operacao_           := 'D';
                  ELSE
                      tabRegistro(linha).codigoCliente_New_ := NULL;
                      tabRegistro(linha).operacao_      := 'E';
            END CASE;

         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_CARTEIRA_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER EACH ROW;

      AFTER STATEMENT IS
         BEGIN
            IF tabRegistro.COUNT > 0 THEN
               FOR i IN 1..tabRegistro.LAST LOOP
                  IF  tabRegistro(i).operacao_ = 'I' THEN 
                     IF C_Customer_Portfolio_Api.Get_Add_To_Sales_Center(vendor_id_ => tabRegistro(i).codigoVendedor_New_) = 'TRUE' 
                        AND tabRegistro(i).carteiraPadrao_New_ = 'TRUE'
                      THEN

                         C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                         code_ => tabRegistro(i).codigoCliente_New_,
                                                                         entity_ => 'CL',
                                                                         operacao_ =>  tabRegistro(linha).operacao_);
                       END IF;
                  END IF;
                  
                  IF  tabRegistro(i).operacao_ = 'U' THEN 

                     CASE WHEN C_Customer_Portfolio_Api.Get_Add_To_Sales_Center(vendor_id_ => tabRegistro(i).codigoVendedor_New_) = 'TRUE' 
                               AND tabRegistro(i).carteiraPadrao_New_ = 'TRUE' 
                               
                             THEN C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                                  code_ => tabRegistro(i).codigoCliente_New_,
                                                                                  entity_ => 'CL',
	                                                                               operacao_ =>  tabRegistro(linha).operacao_);
                                                                                  
                          WHEN C_Customer_Portfolio_Api.Get_Add_To_Sales_Center(vendor_id_ => tabRegistro(i).codigoVendedor_New_) = 'TRUE' 
                               AND tabRegistro(i).carteiraPadrao_New_ = 'FALSE' 
                               AND tabRegistro(i).carteiraPadrao_Old_ = 'TRUE'
                               
                             THEN C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                                  code_ => tabRegistro(i).codigoCliente_New_,
                                                                                  entity_ => 'CL',
                                                                                  operacao_ =>  tabRegistro(linha).operacao_);
                     END CASE;                                                             
                  END IF;
                  /*
                  IF  tabRegistro(i).operacao_ = 'D' THEN 
                     IF C_Customer_Portfolio_Api.Get_Add_To_Sales_Center(vendor_id_ => tabRegistro(i).codigoVendedor_Old_) = 'TRUE' 
                        AND tabRegistro(i).carteiraPadrao_Old_ = 'TRUE'
                      THEN

                         C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                         code_ => tabRegistro(i).codigoCliente_Old_,
                                                                         entity_ => 'CL',
                                                                         operacao_ =>  tabRegistro(linha).operacao_);
                       END IF;
                  END IF;
                  */
               END LOOP;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_CARTEIRA_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER STATEMENT;
END C_INT_CONSUMER_CARTEIRA_TRG;
