package com.example.spiffe;

import javafx.application.Platform;
import javafx.collections.FXCollections;
import javafx.collections.ObservableList;
import javafx.fxml.FXML;
import javafx.scene.control.*;
import javafx.scene.control.cell.PropertyValueFactory;
import javafx.scene.paint.Color;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class HelloController {
    // Status Labels
    @FXML private Label statusLabel;
    @FXML private Label registrationsStatusLabel;
    @FXML private Label agentsStatusLabel;
    @FXML private Label metricsStatusLabel;

    // Workload Registrations Tab
    @FXML private TableView<RegistrationEntry> registrationsTable;
    @FXML private TableColumn<RegistrationEntry, String> regIdColumn;
    @FXML private TableColumn<RegistrationEntry, String> regParentIdColumn;
    @FXML private TableColumn<RegistrationEntry, String> regSelectorsColumn;

    // Agent Status Tab
    @FXML private TableView<AgentStatus> agentsTable;
    @FXML private TableColumn<AgentStatus, String> agentNameColumn;
    @FXML private TableColumn<AgentStatus, String> agentStatusColumn;
    @FXML private TableColumn<AgentStatus, String> agentNodeColumn;
    @FXML private TableColumn<AgentStatus, String> agentVersionColumn;
    @FXML private TableColumn<AgentStatus, String> agentUptimeColumn;

    // Metrics Tab
    @FXML private Label serverStatusLabel;
    @FXML private Label serverUptimeLabel;
    @FXML private Label serverVersionLabel;
    @FXML private Label totalRegistrationsLabel;
    @FXML private Label nodeRegistrationsLabel;
    @FXML private Label workloadRegistrationsLabel;
    @FXML private Label totalAgentsLabel;
    @FXML private Label healthyAgentsLabel;
    @FXML private Label unhealthyAgentsLabel;
    @FXML private Label totalWorkloadsLabel;
    @FXML private Label activeWorkloadsLabel;
    @FXML private Label pendingWorkloadsLabel;

    // Settings Tab
    @FXML private TextField serverContextField;
    @FXML private TextField workloadContextField;
    @FXML private TextField refreshIntervalField;

    // Data models
    private final ObservableList<RegistrationEntry> registrationEntries = FXCollections.observableArrayList();
    private final ObservableList<AgentStatus> agentStatuses = FXCollections.observableArrayList();

    // Settings
    private String serverContext = "spire-server-cluster";
    private String workloadContext = "workload-cluster";
    private int refreshInterval = 30; // seconds

    // Background refresh
    private ScheduledExecutorService scheduler;

    @FXML
    public void initialize() {
        // Initialize tables
        initializeRegistrationsTable();
        initializeAgentsTable();

        // Load settings
        loadSettings();

        // Start background refresh
        startBackgroundRefresh();

        // Initial data load
        refreshAll();
    }

    private void initializeRegistrationsTable() {
        regIdColumn.setCellValueFactory(new PropertyValueFactory<>("id"));
        regParentIdColumn.setCellValueFactory(new PropertyValueFactory<>("parentId"));
        regSelectorsColumn.setCellValueFactory(new PropertyValueFactory<>("selectors"));
        registrationsTable.setItems(registrationEntries);
    }

    private void initializeAgentsTable() {
        agentNameColumn.setCellValueFactory(new PropertyValueFactory<>("name"));
        agentStatusColumn.setCellValueFactory(new PropertyValueFactory<>("status"));
        agentNodeColumn.setCellValueFactory(new PropertyValueFactory<>("node"));
        agentVersionColumn.setCellValueFactory(new PropertyValueFactory<>("version"));
        agentUptimeColumn.setCellValueFactory(new PropertyValueFactory<>("uptime"));
        agentsTable.setItems(agentStatuses);

        // Set cell factory for status column to color cells based on status
        agentStatusColumn.setCellFactory(column -> new TableCell<>() {
            @Override
            protected void updateItem(String item, boolean empty) {
                super.updateItem(item, empty);

                if (item == null || empty) {
                    setText(null);
                    setStyle("");
                } else {
                    setText(item);
                    if ("Healthy".equals(item)) {
                        setTextFill(Color.GREEN);
                    } else if ("Unhealthy".equals(item)) {
                        setTextFill(Color.RED);
                    } else {
                        setTextFill(Color.BLACK);
                    }
                }
            }
        });
    }

    private void loadSettings() {
        // In a real application, these would be loaded from a configuration file or preferences
        serverContext = serverContextField.getText();
        workloadContext = workloadContextField.getText();
        try {
            refreshInterval = Integer.parseInt(refreshIntervalField.getText());
        } catch (NumberFormatException e) {
            refreshInterval = 30;
            refreshIntervalField.setText("30");
        }
    }

    private void startBackgroundRefresh() {
        if (scheduler != null && !scheduler.isShutdown()) {
            scheduler.shutdown();
        }

        scheduler = Executors.newSingleThreadScheduledExecutor();
        scheduler.scheduleAtFixedRate(this::refreshAll, refreshInterval, refreshInterval, TimeUnit.SECONDS);
    }

    private void refreshAll() {
        refreshRegistrations();
        refreshAgents();
        refreshMetrics();
    }

    @FXML
    protected void onRefreshRegistrationsClick() {
        refreshRegistrations();
    }

    @FXML
    protected void onRefreshAgentsClick() {
        refreshAgents();
    }

    @FXML
    protected void onRefreshMetricsClick() {
        refreshMetrics();
    }

    @FXML
    protected void onSaveSettingsClick() {
        loadSettings();
        startBackgroundRefresh();
        statusLabel.setText("Settings saved");
    }

    private void refreshRegistrations() {
        registrationsStatusLabel.setText("Status: Loading...");

        // Run in background thread
        new Thread(() -> {
            try {
                List<RegistrationEntry> entries = fetchRegistrationEntries();

                // Update UI on JavaFX thread
                Platform.runLater(() -> {
                    registrationEntries.clear();
                    registrationEntries.addAll(entries);
                    registrationsStatusLabel.setText("Status: Loaded " + entries.size() + " entries");
                    updateRegistrationMetrics(entries);
                });
            } catch (Exception e) {
                Platform.runLater(() -> {
                    registrationsStatusLabel.setText("Status: Error - " + e.getMessage());
                });
            }
        }).start();
    }

    private void refreshAgents() {
        agentsStatusLabel.setText("Status: Loading...");

        // Run in background thread
        new Thread(() -> {
            try {
                List<AgentStatus> agents = fetchAgentStatuses();

                // Update UI on JavaFX thread
                Platform.runLater(() -> {
                    agentStatuses.clear();
                    agentStatuses.addAll(agents);
                    agentsStatusLabel.setText("Status: Loaded " + agents.size() + " agents");
                    updateAgentMetrics(agents);
                });
            } catch (Exception e) {
                Platform.runLater(() -> {
                    agentsStatusLabel.setText("Status: Error - " + e.getMessage());
                });
            }
        }).start();
    }

    private void refreshMetrics() {
        metricsStatusLabel.setText("Status: Loading...");

        // Run in background thread
        new Thread(() -> {
            try {
                // Fetch server health
                String serverStatus = fetchServerStatus();
                String serverUptime = fetchServerUptime();
                String serverVersion = fetchServerVersion();

                // Update UI on JavaFX thread
                Platform.runLater(() -> {
                    serverStatusLabel.setText("Status: " + serverStatus);
                    serverUptimeLabel.setText("Uptime: " + serverUptime);
                    serverVersionLabel.setText("Version: " + serverVersion);
                    metricsStatusLabel.setText("Status: Loaded");
                });
            } catch (Exception e) {
                Platform.runLater(() -> {
                    metricsStatusLabel.setText("Status: Error - " + e.getMessage());
                });
            }
        }).start();
    }

    private List<RegistrationEntry> fetchRegistrationEntries() throws IOException {
        List<RegistrationEntry> entries = new ArrayList<>();

        // In a real application, this would use the Kubernetes API to execute a command in the SPIRE server pod
        // For demonstration, we'll simulate some entries
        entries.add(new RegistrationEntry("spiffe://example.org/workload/service1", 
                                         "spiffe://example.org/agent/k8s_psat/cluster/spire-agent",
                                         "k8s:ns:workload,k8s:sa:default,k8s:pod-label:app:service1"));
        entries.add(new RegistrationEntry("spiffe://example.org/workload/service2", 
                                         "spiffe://example.org/agent/k8s_psat/cluster/spire-agent",
                                         "k8s:ns:workload,k8s:sa:default,k8s:pod-label:app:service2"));
        entries.add(new RegistrationEntry("spiffe://example.org/workload/service3", 
                                         "spiffe://example.org/agent/k8s_psat/cluster/spire-agent",
                                         "k8s:ns:workload,k8s:sa:default,k8s:pod-label:app:service3"));

        return entries;
    }

    private List<AgentStatus> fetchAgentStatuses() throws IOException {
        List<AgentStatus> agents = new ArrayList<>();

        // In a real application, this would use the Kubernetes API to get the status of SPIRE agent pods
        // For demonstration, we'll simulate some agents
        agents.add(new AgentStatus("spire-agent-1", "Healthy", "node1", "1.6.3", "2d 5h 30m"));
        agents.add(new AgentStatus("spire-agent-2", "Healthy", "node2", "1.6.3", "2d 5h 25m"));
        agents.add(new AgentStatus("spire-agent-3", "Unhealthy", "node3", "1.6.3", "0h 15m"));

        return agents;
    }

    private String fetchServerStatus() {
        // In a real application, this would check the SPIRE server's health endpoint
        return "Healthy";
    }

    private String fetchServerUptime() {
        // In a real application, this would get the uptime from the SPIRE server pod
        return "3d 12h 45m";
    }

    private String fetchServerVersion() {
        // In a real application, this would get the version from the SPIRE server pod
        return "1.6.3";
    }

    private void updateRegistrationMetrics(List<RegistrationEntry> entries) {
        int total = entries.size();
        int nodeCount = 0;
        int workloadCount = 0;

        for (RegistrationEntry entry : entries) {
            if (entry.getId().contains("/agent/")) {
                nodeCount++;
            } else if (entry.getId().contains("/workload/")) {
                workloadCount++;
            }
        }

        totalRegistrationsLabel.setText("Total Registrations: " + total);
        nodeRegistrationsLabel.setText("Node Registrations: " + nodeCount);
        workloadRegistrationsLabel.setText("Workload Registrations: " + workloadCount);
    }

    private void updateAgentMetrics(List<AgentStatus> agents) {
        int total = agents.size();
        int healthy = 0;
        int unhealthy = 0;

        for (AgentStatus agent : agents) {
            if ("Healthy".equals(agent.getStatus())) {
                healthy++;
            } else {
                unhealthy++;
            }
        }

        totalAgentsLabel.setText("Total Agents: " + total);
        healthyAgentsLabel.setText("Healthy Agents: " + healthy);
        unhealthyAgentsLabel.setText("Unhealthy Agents: " + unhealthy);

        // Update workload metrics based on agent status
        // In a real application, this would be more sophisticated
        int totalWorkloads = healthy * 3; // Assuming each healthy agent has 3 workloads
        int activeWorkloads = totalWorkloads - unhealthy;
        int pendingWorkloads = unhealthy;

        totalWorkloadsLabel.setText("Total Workloads: " + totalWorkloads);
        activeWorkloadsLabel.setText("Active Workloads: " + activeWorkloads);
        pendingWorkloadsLabel.setText("Pending Workloads: " + pendingWorkloads);
    }

    // Data model classes
    public static class RegistrationEntry {
        private final String id;
        private final String parentId;
        private final String selectors;

        public RegistrationEntry(String id, String parentId, String selectors) {
            this.id = id;
            this.parentId = parentId;
            this.selectors = selectors;
        }

        public String getId() { return id; }
        public String getParentId() { return parentId; }
        public String getSelectors() { return selectors; }
    }

    public static class AgentStatus {
        private final String name;
        private final String status;
        private final String node;
        private final String version;
        private final String uptime;

        public AgentStatus(String name, String status, String node, String version, String uptime) {
            this.name = name;
            this.status = status;
            this.node = node;
            this.version = version;
            this.uptime = uptime;
        }

        public String getName() { return name; }
        public String getStatus() { return status; }
        public String getNode() { return node; }
        public String getVersion() { return version; }
        public String getUptime() { return uptime; }
    }
}
