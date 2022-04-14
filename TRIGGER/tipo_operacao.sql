CREATE OR REPLACE TRIGGER C_INT_CONSUMER_TIPO_OPER_TRG
   FOR INSERT OR UPDATE OR DELETE ON C_PRICE_LIST_AVAIL_WEB_TAB
   COMPOUND TRIGGER
      -- local variables here

      msg_erro_       VARCHAR2(2000);
      linha       NUMBER;
      text_temp_  VARCHAR2(10);

      TYPE rec_type IS RECORD (codigoCliente_ C_PRICE_LIST_AVAIL_WEB_TAB.CUSTOMER_ID%TYPE,
                               listaPrecoOlD_ C_PRICE_LIST_AVAIL_WEB_TAB.PRICE_LIST_NO%TYPE,
                               listaPrecoNew_ C_PRICE_LIST_AVAIL_WEB_TAB.PRICE_LIST_NO%TYPE,
                               operacao_ VARCHAR2(1)
                               );
      TYPE table_type IS TABLE OF rec_type;
      tabRegistro table_type := table_type();

      AFTER EACH ROW IS
         BEGIN
            tabRegistro.EXTEND;
            linha := tabRegistro.LAST();
            tabRegistro(linha).codigoCliente_ := :NEW.CUSTOMER_ID;
            tabRegistro(linha).listaPrecoOlD_ := :OLD.PRICE_LIST_NO;
            tabRegistro(linha).listaPrecoNew_ := :NEW.PRICE_LIST_NO;

            CASE WHEN INSERTING THEN
                     tabRegistro(linha).operacao_      := 'I';

                 WHEN UPDATING THEN
                     tabRegistro(linha).operacao_      := 'U';

                  WHEN DELETING THEN
                      tabRegistro(linha).operacao_      := 'D';
                  ELSE
                      tabRegistro(linha).operacao_      := 'E';
            END CASE;

         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_TIPO_OPER_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_); 
      END AFTER EACH ROW;

      AFTER STATEMENT IS
         BEGIN
            IF tabRegistro.COUNT > 0 THEN
               FOR i IN 1..tabRegistro.LAST LOOP
                  IF C_INT_MAGENTO_CONSU_UTIL_API.get_existe_cliente_ativo_cart(tabRegistro(i).codigoCliente_) = 'S' THEN
                     IF C_INT_MAGENTO_CONSU_UTIL_API.get_lista_preco_ativa(tabRegistro(i).listaPrecoOlD_ ) = 'S' OR
                        C_INT_MAGENTO_CONSU_UTIL_API.get_lista_preco_ativa(tabRegistro(i).listaPrecoNew_ ) = 'S'   
                     THEN

                          C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER, 
                                                                     code_ => tabRegistro(i).codigoCliente_, 
                                                                     entity_ => 'CL', 
                                                                     operacao_ => tabRegistro(i).operacao_ );
                     END IF;
                  END IF;
               END LOOP;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_TIPO_OPER_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_); 
      END AFTER STATEMENT;
END C_INT_CONSUMER_TIPO_OPER_TRG;
