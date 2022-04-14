CREATE OR REPLACE TRIGGER C_INT_CONSUMER_CONDPGTO_H_TRG
   BEFORE INSERT OR UPDATE OR DELETE ON PAYMENT_TERM_TAB
   FOR EACH ROW
DECLARE
      -- local variables here
      code__       PAYMENT_TERM_TAB.PAY_TERM_ID%TYPE;
      operacao__   VARCHAR2(1);
      msg_erro_    VARCHAR2(2000);
BEGIN
   IF :NEW.C_DIVISION = 'M' THEN
     code__ := :NEW.PAY_TERM_ID;
   
     IF INSERTING THEN
       operacao__ := 'I';
     END IF;

     IF UPDATING THEN
       operacao__ := 'U';
     END IF;

     IF DELETING THEN
       operacao__ := 'D';
     END IF;
     
     BEGIN
       C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_NOTIFICACAO(user_ => USER, code_ => code__, entity_ => 'CP', operacao_ => operacao__);
     EXCEPTION WHEN OTHERS THEN
        msg_erro_ := 'ERROR  TRIGGER - C_INT_CONSUMER_COND_PGTO_TRG: '|| substr(sqlerrm,1,1600);
        C_INT_MAGENTO_CONSU_UTIL_API.GRAVAR_LOG_TRIGGER(USER, msg_erro_);
     END;

   END IF;  
END C_INT_CONSUMER_CONDPGTO_H_TRG;
