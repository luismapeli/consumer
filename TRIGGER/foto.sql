CREATE OR REPLACE TRIGGER C_INT_CONSUMER_FOTO_TRG
   FOR INSERT OR UPDATE OR DELETE ON BINARY_OBJECT_DATA_BLOCK_TAB
   COMPOUND TRIGGER
      -- local variables here
      msg_erro_    VARCHAR2(2000);
      linha         NUMBER;

      TYPE rec_type IS RECORD (idBlodNew_ BINARY_OBJECT_DATA_BLOCK_TAB.Blob_Id%TYPE,
                               idBlodOld_ BINARY_OBJECT_DATA_BLOCK_TAB.Blob_Id%TYPE,
                               part_no_ PART_CATALOG.part_no%TYPE,
                               operacao_ VARCHAR2(1)
                               );
      TYPE table_type IS TABLE OF rec_type;
      tabRegistro table_type := table_type();

      CURSOR get_cod_produto (id_blob_ NUMBER) IS SELECT pc.PART_NO
                                                  FROM PART_CATALOG pc
                                                  WHERE PICTURE_ID1 = id_blob_
                                                     OR PICTURE_ID2 = id_blob_
                                                     OR PICTURE_ID3 = id_blob_
                                                     OR PICTURE_ID4 = id_blob_
                                                     OR PICTURE_ID5 = id_blob_
                                                     OR PICTURE_ID6 = id_blob_
                                                     OR PICTURE_ID7 = id_blob_
                                                     OR PICTURE_ID8 = id_blob_;


      AFTER EACH ROW IS
         BEGIN
            tabRegistro.EXTEND;
            linha := tabRegistro.LAST();
            tabRegistro(linha).idBlodNew_       := :NEW.BLOB_ID;
            tabRegistro(linha).idBlodOld_       := :OLD.BLOB_ID;

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
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_FOTO_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER EACH ROW;

      AFTER STATEMENT IS
         BEGIN
            
        
            IF tabRegistro.COUNT > 0 THEN
               FOR i IN 1..tabRegistro.LAST LOOP
                  OPEN get_cod_produto(NVL(tabRegistro(i).idBlodNew_,tabRegistro(i).idBlodOld_));
                  FETCH get_cod_produto INTO tabRegistro(i).part_no_;
                  CLOSE get_cod_produto;
                  RAISE_APPLICATION_ERROR (-20401,tabRegistro(i).part_no_ || ' -' || NVL(tabRegistro(i).idBlodNew_,tabRegistro(i).idBlodOld_));   
               
                  IF C_INT_MAGENTO_CONSU_UTIL_API.get_existe_prod_lista_preco(tabRegistro(i).part_no_) = 'S' THEN
                        C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                        code_ => tabRegistro(i).idBlodNew_,
                                                                        entity_ => 'FT',
                                                                        operacao_ => tabRegistro(i).operacao_);

                  END IF;
               END LOOP;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_FOTO_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER STATEMENT;
END C_INT_CONSUMER_FOTO_TRG;
