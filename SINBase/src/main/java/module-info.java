module devfamily.sinbase.sinbase {
    requires javafx.controls;
    requires javafx.fxml;

    requires org.controlsfx.controls;
    requires net.synedra.validatorfx;
    requires org.kordamp.ikonli.javafx;

    opens devfamily.sinbase.sinbase to javafx.fxml;
    exports devfamily.sinbase.sinbase;
}