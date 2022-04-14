CREATE OR REPLACE TRIGGER C_INT_CONSUMER_IMPOSTOS_TRG
   FOR INSERT OR UPDATE OR DELETE ON TAX_PART_TAB
   COMPOUND TRIGGER
      -- local variables here
      msg_erro_    VARCHAR2(2000);
      linha         NUMBER;

      TYPE rec_type IS RECORD (codigoProdutoNew_      TAX_PART_TAB.PART_NO%TYPE,
                               codigoProdutoOld_      TAX_PART_TAB.PART_NO%TYPE,
                               tipoMaterialFiscalNew_ TAX_PART_TAB.FISCAL_PART_TYPE%TYPE,
                               tipoMaterialFiscalOld_ TAX_PART_TAB.FISCAL_PART_TYPE%TYPE,
                               operacao_ VARCHAR2(1)
                               );
      TYPE table_type IS TABLE OF rec_type;
      tabRegistro table_type := table_type();

      AFTER EACH ROW IS
         BEGIN
            tabRegistro.EXTEND;
            linha := tabRegistro.LAST();
            tabRegistro(linha).codigoProdutoNew_       := :NEW.PART_NO;
            tabRegistro(linha).codigoProdutoOld_       := :OLD.PART_NO;
            tabRegistro(linha).tipoMaterialFiscalNew_  := :NEW.TAX_PART_ID;
            tabRegistro(linha).tipoMaterialFiscalOld_  := :OLD.TAX_PART_ID;

            CASE WHEN INSERTING THEN
                     tabRegistro(linha).operacao_          := 'I';

                 WHEN UPDATING THEN
                     tabRegistro(linha).operacao_          := 'U';

                  WHEN DELETING THEN
                     tabRegistro(linha).operacao_          := 'D';

                  ELSE
                     tabRegistro(linha).operacao_           := 'E';
            END CASE;

         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_IMPOSTOS_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER EACH ROW;

      AFTER STATEMENT IS
         BEGIN
            IF tabRegistro.COUNT > 0 THEN
               FOR i IN 1..tabRegistro.LAST LOOP
                  IF C_INT_MAGENTO_CONSU_UTIL_API.get_existe_prod_lista_preco(tabRegistro(i).codigoProdutoNew_) = 'S' THEN
                        C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                        code_ => tabRegistro(i).tipoMaterialFiscalNew_,
                                                                        entity_ => 'IC',
                                                                        operacao_ => tabRegistro(i).operacao_);
                         IF C_INT_MAGENTO_CONSU_UTIL_API.get_existe_notif_cad_prod(tabRegistro(i).codigoProdutoNew_) = 'N' THEN
                            C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                            code_ => tabRegistro(i).codigoProdutoNew_,
                                                                            entity_ => 'PR',
                                                                            operacao_ => 'I' );    
                         END IF;                                               
                  END IF;
               END LOOP;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_IMPOSTOS_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER STATEMENT;
END C_INT_CONSUMER_IMPOSTOS_TRG;
