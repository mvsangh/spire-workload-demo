// SPIRE/SPIFFE Demo UI Logic

document.addEventListener('DOMContentLoaded', function() {
    const runDemoBtn = document.getElementById('runDemoBtn');
    const loading = document.getElementById('loading');
    const ordersSection = document.getElementById('ordersSection');
    const ordersContainer = document.getElementById('ordersContainer');

    // Status elements for Pattern 1 (Frontend to Backend)
    const fe2beStatus = document.getElementById('fe2beStatus');
    const fe2beMessage = document.getElementById('fe2beMessage');

    // Status elements for Pattern 2 (Backend to Database)
    const be2dbStatus = document.getElementById('be2dbStatus');
    const be2dbMessage = document.getElementById('be2dbMessage');

    runDemoBtn.addEventListener('click', async function() {
        // Disable button and show loading
        runDemoBtn.disabled = true;
        loading.classList.remove('hidden');
        ordersSection.classList.add('hidden');

        // Reset status indicators
        resetStatus(fe2beStatus, fe2beMessage);
        resetStatus(be2dbStatus, be2dbMessage);

        try {
            // Call the backend demo endpoint
            const response = await fetch('/api/demo', {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json'
                }
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }

            const result = await response.json();

            // Update Pattern 1 status (Frontend to Backend via Envoy SDS)
            updateConnectionStatus(
                fe2beStatus,
                fe2beMessage,
                result.frontend_to_backend
            );

            // Update Pattern 2 status (Backend to Database via spiffe-helper)
            updateConnectionStatus(
                be2dbStatus,
                be2dbMessage,
                result.backend_to_database
            );

            // Display orders if successful
            if (result.orders && result.orders.length > 0) {
                displayOrders(result.orders);
                ordersSection.classList.remove('hidden');
            }

        } catch (error) {
            console.error('Demo failed:', error);

            // Show error for Pattern 1 (frontend-to-backend connection failed)
            updateConnectionStatus(
                fe2beStatus,
                fe2beMessage,
                {
                    success: false,
                    message: `Connection failed: ${error.message}`,
                    pattern: 'envoy-sds'
                }
            );

            // Pattern 2 is unknown if we couldn't reach backend
            updateConnectionStatus(
                be2dbStatus,
                be2dbMessage,
                {
                    success: false,
                    message: 'Unable to determine (frontend-to-backend failed)',
                    pattern: 'spiffe-helper'
                }
            );
        } finally {
            // Re-enable button and hide loading
            runDemoBtn.disabled = false;
            loading.classList.add('hidden');
        }
    });

    function resetStatus(statusElement, messageElement) {
        statusElement.className = 'status-indicator';
        statusElement.innerHTML = `
            <span class="status-icon">⏳</span>
            <span class="status-text">Checking...</span>
        `;
        messageElement.textContent = '';
    }

    function updateConnectionStatus(statusElement, messageElement, connectionStatus) {
        if (connectionStatus.success) {
            statusElement.className = 'status-indicator status-success';
            statusElement.innerHTML = `
                <span class="status-icon"></span>
                <span class="status-text">SUCCESS</span>
            `;
        } else {
            statusElement.className = 'status-indicator status-error';
            statusElement.innerHTML = `
                <span class="status-icon"></span>
                <span class="status-text">FAILED</span>
            `;
        }

        messageElement.textContent = connectionStatus.message || '';
    }

    function displayOrders(orders) {
        ordersContainer.innerHTML = '';

        orders.forEach(order => {
            const orderCard = document.createElement('div');
            orderCard.className = 'order-card';

            const createdDate = new Date(order.created_at).toLocaleDateString();

            orderCard.innerHTML = `
                <h4>Order #${order.id}</h4>
                <p>${order.description}</p>
                <p><strong>Status:</strong> <span class="order-status ${order.status}">${order.status}</span></p>
                <p><strong>Created:</strong> ${createdDate}</p>
            `;

            ordersContainer.appendChild(orderCard);
        });
    }
});
