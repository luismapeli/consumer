CREATE OR REPLACE TRIGGER IFSRIB.C_INT_CONSUMER_PRECO_TRG
   FOR INSERT OR UPDATE OR DELETE ON SALES_PRICE_LIST_PART_TAB
   COMPOUND TRIGGER
      -- local variables here
      code__      VARCHAR2(20);
      msg_erro_   VARCHAR2(2000);
      linha       NUMBER;

      TYPE rec_type IS RECORD (listaPrecoNew_ SALES_PRICE_LIST_PART_TAB.PRICE_LIST_NO%TYPE,
                               listaPrecoOld_ SALES_PRICE_LIST_PART_TAB.PRICE_LIST_NO%TYPE,
                               codigoProdutoNew_ SALES_PRICE_LIST_PART_TAB.CATALOG_NO%TYPE,
                               codigoProdutoOlD_ SALES_PRICE_LIST_PART_TAB.CATALOG_NO%TYPE,
                               operacao_ VARCHAR2(1)
                               );
      TYPE table_type IS TABLE OF rec_type;
      tabRegistro table_type := table_type();

      CURSOR get_id_mat_impostos (cod_produto_ IN VARCHAR2) IS SELECT a.TAX_PART_ID 
                                                               FROM TAX_PART a
                                                               WHERE PART_NO = cod_produto_
                                                               AND a.FISCAL_PART_TYPE_DB = 2
                                                               AND a.CONTRACT LIKE '%M';

      AFTER EACH ROW IS
         BEGIN
            tabRegistro.EXTEND;
            linha := tabRegistro.LAST();
            tabRegistro(linha).listaPrecoNew_       := :NEW.PRICE_LIST_NO;
            tabRegistro(linha).listaPrecoOld_       := :OLD.PRICE_LIST_NO;
            tabRegistro(linha).codigoProdutoNew_    := :NEW.CATALOG_NO;
            tabRegistro(linha).codigoProdutoOlD_    := :OLD.CATALOG_NO;
            
            CASE WHEN INSERTING THEN
                     tabRegistro(linha).operacao_            := 'I';

                 WHEN UPDATING THEN
                     tabRegistro(linha).operacao_            := 'U';

                  WHEN DELETING THEN
                     tabRegistro(linha).operacao_            := 'D';

                  ELSE
                      tabRegistro(linha).operacao_           := 'E';
            END CASE;

         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_PRECO_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER EACH ROW;

      AFTER STATEMENT IS
         BEGIN
            IF tabRegistro.COUNT > 0 THEN
               FOR i IN 1..tabRegistro.LAST LOOP
                  IF C_INT_MAGENTO_CONSU_UTIL_API.get_lista_preco_ativa(tabRegistro(i).listaPrecoNew_ ) = 'S' THEN
                       code__ := tabRegistro(i).listaPrecoNew_ ||'^'||tabRegistro(i).codigoProdutoNew_;
                       C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                     code_ => code__,
                                                                     entity_ => 'BP',
                                                                     operacao_ => tabRegistro(i).operacao_ );
                       IF tabRegistro(i).operacao_ = 'I' AND C_INT_MAGENTO_CONSU_UTIL_API.get_existe_notif_cad_prod(tabRegistro(i).codigoProdutoNew_) = 'N' THEN
                          C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                           code_ => tabRegistro(i).codigoProdutoNew_,
                                                                           entity_ => 'PR',
                                                                           operacao_ => 'I' );
                          /*    recuperar os IDs do material de impostos */                                                 
                          FOR rec_imp_ in get_id_mat_impostos(tabRegistro(i).codigoProdutoNew_) LOOP
                              C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                      code_ => rec_imp_.TAX_PART_ID,
                                                      entity_ => 'IC',
                                                      operacao_ => 'I' );
                             
                          END LOOP;

                       END IF;                                             
                  END IF;
               END LOOP;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_PRECO_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER STATEMENT;
END C_INT_CONSUMER_PRECO_TRG;
