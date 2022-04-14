CREATE OR REPLACE TRIGGER C_INT_CONSUMER_PRODUTO_TRG
   FOR INSERT OR UPDATE OR DELETE ON PART_CATALOG_TAB
   COMPOUND TRIGGER
      -- local variables here
      msg_erro_    VARCHAR2(2000);
      linha         NUMBER;

      TYPE rec_type IS RECORD (codigoProdutoNew_ PART_CATALOG_TAB.PART_NO%TYPE,
                               codigoProdutoOld_ PART_CATALOG_TAB.PART_NO%TYPE,
                               idFoto01New_ PART_CATALOG_TAB.Picture_Id1%TYPE,
                               idFoto01Old_ PART_CATALOG_TAB.Picture_Id1%TYPE,
                                                            
                               idFoto01MagNew_ PART_CATALOG_TAB.Picture_Id1_Mag_Id%TYPE,
                               idFoto01MagOld_ PART_CATALOG_TAB.Picture_Id1_Mag_Id%TYPE,
                                                          
                               operacao_ VARCHAR2(1)
                               );
      TYPE table_type IS TABLE OF rec_type;
      tabRegistro table_type := table_type();

      AFTER EACH ROW IS
         BEGIN
            tabRegistro.EXTEND;
            linha := tabRegistro.LAST();
            tabRegistro(linha).codigoProdutoNew_     := :NEW.PART_NO;
            tabRegistro(linha).codigoProdutoOld_     := :OLD.PART_NO;

            tabRegistro(linha).idFoto01New_       := :NEW.Picture_Id1;
            tabRegistro(linha).idFoto01Old_       := :OLD.Picture_Id1;
                        
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
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_PRODUTO_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER EACH ROW;

      AFTER STATEMENT IS
         BEGIN
            IF tabRegistro.COUNT > 0 THEN
               FOR i IN 1..tabRegistro.LAST LOOP

                  IF C_INT_MAGENTO_CONSU_UTIL_API.get_existe_prod_lista_preco(tabRegistro(i).codigoProdutoNew_) = 'S' THEN
                     IF C_INT_MAGENTO_CONSU_UTIL_API.get_existe_prod_mat_imposto(tabRegistro(i).codigoProdutoNew_) = 'S' THEN
                        C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                        code_ => tabRegistro(i).codigoProdutoNew_,
                                                                        entity_ => 'PR',
                                                                        operacao_ => tabRegistro(i).operacao_);
                       CASE WHEN -- FOTO 01 NOVO
                                NVL(tabRegistro(linha).idFoto01New_ ,0) <> 0
                                AND NVL(tabRegistro(linha).idFoto01Old_ ,0) = 0 

                             THEN
                                  C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                                  code_ => '1' || '^' || tabRegistro(i).codigoProdutoNew_ || '^' || NVL(tabRegistro(linha).idFoto01New_,0),
                                                                                  entity_ => 'FT',
                                                                                  operacao_ => 'I');
                                                                              
                              WHEN -- FOTO 01 ALTERACAO
                                NVL(tabRegistro(linha).idFoto01New_ ,0) <> 0
                                AND NVL(tabRegistro(linha).idFoto01Old_ ,0) <> 0 
                              THEN
                                  C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                                  code_ => '1' || '^' || tabRegistro(i).codigoProdutoNew_ || '^' || tabRegistro(linha).idFoto01New_,
                                                                                  entity_ => 'FT',
                                                                                  operacao_ => 'U');

                              WHEN -- FOTO 01 DELECAO
                                NVL(tabRegistro(linha).idFoto01New_ ,0) = 0
                                AND NVL(tabRegistro(linha).idFoto01Old_ ,0) <> 0 
                              THEN
                                  C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                                  code_ => '1'|| '^' || tabRegistro(i).codigoProdutoNew_ || '^' || tabRegistro(linha).idFoto01Old_,
                                                                                  entity_ => 'FT',
                                                                                  operacao_ => 'D');
                        END CASE;
                     
                     END IF;
                  END IF;
               END LOOP;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_PRODUTO_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER STATEMENT;
END C_INT_CONSUMER_PRODUTO_TRG;
