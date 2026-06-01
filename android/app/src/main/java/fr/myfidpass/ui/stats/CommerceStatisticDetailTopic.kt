package fr.myfidpass.ui.stats

import fr.myfidpass.data.dto.BusinessStatsResponse
import fr.myfidpass.data.dto.EvolutionWeekDto

enum class CommerceStatisticDetailTopic(val screenTitle: String) {
    ActiveClients("Clients actifs"),
    NewMembers("Nouveaux membres"),
    CardsIssued("Cartes émises"),
    ;

    fun primaryMetric(stats: BusinessStatsResponse?): String {
        if (stats == null) return "—"
        return when (this) {
            ActiveClients -> (stats.membersCount ?: 0).toString()
            NewMembers -> (stats.newMembersLast30Days ?: stats.newMembersLast7Days ?: 0).toString()
            CardsIssued -> (stats.membersCount ?: 0).toString()
        }
    }

    fun chartValues(evolution: List<EvolutionWeekDto>): List<Float> {
        return when (this) {
            ActiveClients -> evolution.mapNotNull { it.operationsCount?.toFloat() }
            NewMembers -> {
                val m = evolution.mapNotNull { it.membersCount?.toFloat() }
                if (m.size < 2) return m
                (1 until m.size).map { i -> (m[i] - m[i - 1]).coerceAtLeast(0f) }
            }
            CardsIssued -> evolution.mapNotNull { it.membersCount?.toFloat() }
        }
    }

    val chartFootnote: String
        get() = when (this) {
            ActiveClients -> "Courbe : opérations par intervalle — fréquentation magasin."
            NewMembers -> "Courbe : variation du nombre de membres entre intervalles."
            CardsIssued -> "Courbe : membres cumulés (fin de chaque intervalle)."
        }
    }
