module com.example.spiffe {
    requires javafx.controls;
    requires javafx.fxml;


    opens com.example.spiffe to javafx.fxml;
    exports com.example.spiffe;
}