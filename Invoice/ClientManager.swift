//
//  ClientManager.swift
//  Invoice
//
//  Client management with persistence
//

import Foundation
import SwiftUI

// MARK: - Client Manager
@MainActor
class ClientManager: ObservableObject {
    static let shared = ClientManager()
    
    @Published var clients: [Client] = []
    
    private let userDefaultsKey = "SavedClients"
    
    private init() {
        loadClients()
    }
    
    // Add a new client
    func addClient(_ client: Client) {
        clients.append(client)
        saveClients()
    }
    
    // Update an existing client
    func updateClient(_ client: Client) {
        if let index = clients.firstIndex(where: { $0.id == client.id }) {
            clients[index] = client
            saveClients()
        }
    }
    
    // Delete a client
    func deleteClient(_ client: Client) {
        clients.removeAll { $0.id == client.id }
        saveClients()
    }
    
    // Get a client by ID
    func getClient(byId id: UUID) -> Client? {
        return clients.first { $0.id == id }
    }
    
    // Save clients to UserDefaults
    private func saveClients() {
        if let encoded = try? JSONEncoder().encode(clients) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    // Load clients from UserDefaults
    private func loadClients() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([Client].self, from: data) {
            clients = decoded
        }
    }
}

