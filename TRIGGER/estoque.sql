CREATE OR REPLACE TRIGGER C_INT_CONSUMER_ESTOQUE_TRG
   FOR INSERT OR UPDATE OR DELETE ON INVENTORY_PART_IN_STOCK_TAB
   COMPOUND TRIGGER
      -- local variables here
      msg_erro_    VARCHAR2(2000);
      linha         NUMBER;

      TYPE rec_type IS RECORD (codigoProdutoNew_ INVENTORY_PART_IN_STOCK_TAB.PART_NO%TYPE,
                               codigoProdutoOld_ INVENTORY_PART_IN_STOCK_TAB.PART_NO%TYPE,
                               siteNew_          INVENTORY_PART_IN_STOCK_TAB.CONTRACT%TYPE,
                               siteOld_          INVENTORY_PART_IN_STOCK_TAB.CONTRACT%TYPE,
                               LocationTypeNew_  INVENTORY_PART_IN_STOCK_TAB.Location_Type%TYPE,
                               LocationTypeOld_  INVENTORY_PART_IN_STOCK_TAB.Location_Type%TYPE,
                               qtyOnhandNew_     INVENTORY_PART_IN_STOCK_TAB.QTY_ONHAND%TYPE,
                               qtyOnhandOld_     INVENTORY_PART_IN_STOCK_TAB.QTY_ONHAND%TYPE,
                               qtyReservedNew_   INVENTORY_PART_IN_STOCK_TAB.QTY_RESERVED%TYPE,
                               qtyReservedOld_   INVENTORY_PART_IN_STOCK_TAB.QTY_RESERVED%TYPE,
                               availabilitycontrolIdNew_   INVENTORY_PART_IN_STOCK_TAB.AVAILABILITY_CONTROL_ID%TYPE,
                               availabilitycontrolIdOld_   INVENTORY_PART_IN_STOCK_TAB.AVAILABILITY_CONTROL_ID%TYPE,
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
            tabRegistro(linha).siteNew_              := :NEW.CONTRACT;
            tabRegistro(linha).siteOld_              := :OLD.CONTRACT;
            tabRegistro(linha).LocationTypeNew_      := :NEW.LOCATION_TYPE;
            tabRegistro(linha).LocationTypeOld_      := :OLD.LOCATION_TYPE;
            tabRegistro(linha).qtyOnhandNew_         := :NEW.QTY_ONHAND;
            tabRegistro(linha).qtyOnhandOld_         := :OLD.QTY_ONHAND;
            tabRegistro(linha).qtyReservedNew_       := :NEW.QTY_RESERVED;
            tabRegistro(linha).qtyReservedOld_       := :OLD.QTY_RESERVED;
            tabRegistro(linha).availabilitycontrolIdNew_       := :NEW.AVAILABILITY_CONTROL_ID;
            tabRegistro(linha).availabilitycontrolIdOld_       := :OLD.AVAILABILITY_CONTROL_ID;

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
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_ESTOQUE_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER EACH ROW;

      AFTER STATEMENT IS
         BEGIN
            IF tabRegistro.COUNT > 0 THEN
               FOR i IN 1..tabRegistro.LAST LOOP
                  IF tabRegistro(i).LocationTypeNew_ IN ('PICKING','DEEP')
                     AND tabRegistro(i).siteNew_ IN ('SC19M', 'MG09B', 'SC19P')
                     AND (NVL(tabRegistro(i).qtyOnhandNew_,0) <> NVL(tabRegistro(i).qtyOnhandOld_,0)
                            OR NVL(tabRegistro(i).qtyReservedNew_,0) <> NVL(tabRegistro(i).qtyReservedOld_,0)
                            OR NVL(tabRegistro(i).availabilitycontrolIdNew_,'DuMmy') <> NVL(tabRegistro(i).availabilitycontrolIdOld_,'DuMmy')
                            ) THEN
                        IF C_INT_MAGENTO_CONSU_UTIL_API.get_existe_prod_lista_preco(tabRegistro(i).codigoProdutoNew_) = 'S' THEN
                           C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER,
                                                                           code_ => tabRegistro(i).codigoProdutoNew_,
                                                                           entity_ => 'PR',
                                                                           operacao_ => tabRegistro(i).operacao_);
                        END IF;
                  END IF;
                  
               END LOOP;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_ESTOQUE_TRG: '|| substr(sqlerrm,1,1600);
                C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
      END AFTER STATEMENT;
END C_INT_CONSUMER_ESTOQUE_TRG;
