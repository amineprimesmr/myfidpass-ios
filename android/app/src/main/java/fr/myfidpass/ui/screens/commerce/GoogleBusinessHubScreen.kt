package fr.myfidpass.ui.screens.commerce

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.myfidpass.data.dto.GoogleBusinessPostRow
import fr.myfidpass.data.dto.GoogleBusinessReviewRow
import fr.myfidpass.data.dto.GoogleBusinessStatusResponse
import fr.myfidpass.data.repo.DashboardRepository
import fr.myfidpass.util.openInCustomTab
import fr.myfidpass.util.optHttpUrl
import kotlinx.coroutines.launch
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoogleBusinessHubScreen(
    repository: DashboardRepository,
    snackbarHostState: SnackbarHostState,
    onBack: () -> Unit,
) {
    val slug = repository.currentSlug()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var tab by remember { mutableIntStateOf(0) }
    var loading by remember { mutableStateOf(true) }
    var status by remember { mutableStateOf<GoogleBusinessStatusResponse?>(null) }
    var reviews by remember { mutableStateOf<List<GoogleBusinessReviewRow>>(emptyList()) }
    var posts by remember { mutableStateOf<List<GoogleBusinessPostRow>>(emptyList()) }
    var questions by remember { mutableStateOf<List<Pair<String, String>>>(emptyList()) }
    var insightsText by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var replyDrafts by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var answerDrafts by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var postSummary by remember { mutableStateOf("") }
    var posting by remember { mutableStateOf(false) }
    var aiReviewId by remember { mutableStateOf<String?>(null) }

    fun reload() {
        if (slug == null) return
        scope.launch {
            loading = true
            error = null
            runCatching {
                status = repository.googleBusinessStatus(slug)
                reviews = repository.googleBusinessReviews(slug, 30).reviews
                posts = repository.googleBusinessPosts(slug, 15).posts
                val qJson = repository.googleBusinessQuestions(slug)
                questions = qJson["questions"]?.jsonArray?.mapNotNull { el ->
                    val o = el.jsonObject
                    val id = o["id"]?.jsonPrimitive?.content ?: return@mapNotNull null
                    val text = o["text"]?.jsonPrimitive?.content ?: o["question"]?.jsonPrimitive?.content ?: "Question"
                    id to text
                }.orEmpty()
                val ins = repository.googleBusinessInsights(slug, 30)
                insightsText = ins.entries.joinToString("\n") { (k, v) ->
                    "$k : ${v.toString().trim('"')}"
                }.ifBlank { "Aucune statistique pour l’instant." }
            }.onFailure { error = it.message }
            loading = false
        }
    }

    LaunchedEffect(slug) {
        if (slug == null) loading = false else reload()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Google Business") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Retour")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            TabRow(selectedTabIndex = tab) {
                Tab(selected = tab == 0, onClick = { tab = 0 }, text = { Text("Avis") })
                Tab(selected = tab == 1, onClick = { tab = 1 }, text = { Text("Posts") })
                Tab(selected = tab == 2, onClick = { tab = 2 }, text = { Text("Q&R") })
                Tab(selected = tab == 3, onClick = { tab = 3 }, text = { Text("Stats") })
            }
            Column(
                Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
            ) {
                if (loading) {
                    CircularProgressIndicator()
                    return@Column
                }
                error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
                status?.let { ConnectionCard(it, onRetryPending = {
                    if (slug == null) return@ConnectionCard
                    scope.launch {
                        runCatching {
                            repository.googleBusinessRetryPendingLocation(slug)
                            snackbarHostState.showSnackbar("Nouvelle tentative de liaison")
                            reload()
                        }.onFailure { snackbarHostState.showSnackbar(it.message ?: "Erreur") }
                    }
                }) }
                Spacer(Modifier.height(12.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(
                        onClick = {
                            if (slug == null) return@Button
                            scope.launch {
                                runCatching {
                                    repository.socialOAuthGoogleBusinessStart(slug).optHttpUrl()
                                        ?.let { openInCustomTab(context, it) }
                                        ?: snackbarHostState.showSnackbar("OAuth indisponible")
                                }.onFailure { snackbarHostState.showSnackbar(it.message ?: "Erreur") }
                            }
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text("Connecter") }
                    OutlinedButton(
                        onClick = {
                            if (slug == null) return@OutlinedButton
                            scope.launch {
                                runCatching {
                                    repository.googleBusinessReviewsSync(slug)
                                    repository.googleBusinessReviewsMarkAllSeen(slug)
                                    snackbarHostState.showSnackbar("Avis synchronisés")
                                    reload()
                                }.onFailure { snackbarHostState.showSnackbar(it.message ?: "Erreur") }
                            }
                        },
                        modifier = Modifier.weight(1f),
                    ) { Text("Sync avis") }
                }
                Spacer(Modifier.height(16.dp))
                when (tab) {
                    0 -> ReviewsTab(
                        reviews = reviews,
                        replyDrafts = replyDrafts,
                        onReplyChange = { id, txt -> replyDrafts = replyDrafts + (id to txt) },
                        aiReviewId = aiReviewId,
                        onPublishReply = { id, text ->
                            if (slug == null) return@ReviewsTab
                            scope.launch {
                                runCatching {
                                    repository.googleBusinessReviewReply(slug, id, text)
                                    snackbarHostState.showSnackbar("Réponse publiée")
                                    reload()
                                }.onFailure { snackbarHostState.showSnackbar(it.message ?: "Erreur") }
                            }
                        },
                        onAiReply = { id ->
                            if (slug == null) return@ReviewsTab
                            scope.launch {
                                aiReviewId = id
                                runCatching {
                                    val r = repository.googleBusinessReviewReplyAi(slug, id)
                                    val suggestion = r["suggestion"]?.jsonPrimitive?.content
                                        ?: r["comment"]?.jsonPrimitive?.content
                                    if (suggestion != null) {
                                        replyDrafts = replyDrafts + (id to suggestion)
                                        snackbarHostState.showSnackbar("Proposition IA insérée")
                                    } else reload()
                                }.onFailure { snackbarHostState.showSnackbar(it.message ?: "IA indisponible") }
                                aiReviewId = null
                            }
                        },
                        onDeleteReply = { id ->
                            if (slug == null) return@ReviewsTab
                            scope.launch {
                                runCatching {
                                    repository.googleBusinessReviewDeleteReply(slug, id)
                                    reload()
                                }.onFailure { snackbarHostState.showSnackbar(it.message ?: "Erreur") }
                            }
                        },
                    )
                    1 -> PostsTab(
                        posts = posts,
                        postSummary = postSummary,
                        posting = posting,
                        onSummaryChange = { postSummary = it },
                        onPublish = {
                            val text = postSummary.trim()
                            if (text.isEmpty() || slug == null) return@PostsTab
                            scope.launch {
                                posting = true
                                runCatching {
                                    repository.googleBusinessPostCreate(slug, text)
                                    postSummary = ""
                                    reload()
                                    snackbarHostState.showSnackbar("Publication créée")
                                }.onFailure { snackbarHostState.showSnackbar(it.message ?: "Erreur") }
                                posting = false
                            }
                        },
                    )
                    2 -> QnaTab(
                        questions = questions,
                        answerDrafts = answerDrafts,
                        onAnswerChange = { id, t -> answerDrafts = answerDrafts + (id to t) },
                        onSubmit = { id, text ->
                            if (slug == null || text.isBlank()) return@QnaTab
                            scope.launch {
                                runCatching {
                                    repository.googleBusinessQuestionAnswer(slug, id, text.trim())
                                    snackbarHostState.showSnackbar("Réponse publiée")
                                    reload()
                                }.onFailure { snackbarHostState.showSnackbar(it.message ?: "Erreur") }
                            }
                        },
                    )
                    3 -> Text(
                        insightsText ?: "—",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
    }
}

@Composable
private fun ConnectionCard(st: GoogleBusinessStatusResponse, onRetryPending: () -> Unit) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
        Column(Modifier.padding(14.dp)) {
            Text(
                if (st.connected == true) "Google Business connecté" else "Non connecté",
                fontWeight = FontWeight.SemiBold,
            )
            st.locationTitle?.let { Text(it, style = MaterialTheme.typography.bodyMedium) }
            st.counts?.let { c ->
                Text(
                    "${c.total ?: 0} avis · ${c.unreplied ?: 0} sans réponse",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            if (st.locationPending == true) {
                Text("Fiche en cours de liaison…", color = MaterialTheme.colorScheme.error)
                Spacer(Modifier.height(8.dp))
                OutlinedButton(onClick = onRetryPending) { Text("Réessayer la liaison") }
            }
        }
    }
}

@Composable
private fun ReviewsTab(
    reviews: List<GoogleBusinessReviewRow>,
    replyDrafts: Map<String, String>,
    onReplyChange: (String, String) -> Unit,
    aiReviewId: String?,
    onPublishReply: (String, String) -> Unit,
    onAiReply: (String) -> Unit,
    onDeleteReply: (String) -> Unit,
) {
    if (reviews.isEmpty()) {
        Text("Aucun avis synchronisé.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        return
    }
    reviews.forEach { review ->
        val id = review.reviewId.orEmpty()
        ReviewCard(
            review = review,
            reply = replyDrafts[id].orEmpty(),
            aiLoading = aiReviewId == id,
            onReplyChange = { onReplyChange(id, it) },
            onPublishReply = { onPublishReply(id, replyDrafts[id]?.trim().orEmpty()) },
            onAiReply = { onAiReply(id) },
            onDeleteReply = { onDeleteReply(id) },
        )
        Spacer(Modifier.height(10.dp))
    }
}

@Composable
private fun ReviewCard(
    review: GoogleBusinessReviewRow,
    reply: String,
    aiLoading: Boolean,
    onReplyChange: (String) -> Unit,
    onPublishReply: () -> Unit,
    onAiReply: () -> Unit,
    onDeleteReply: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Column(Modifier.padding(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    review.authorName ?: "Client",
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Row {
                    repeat(review.rating ?: 0) {
                        Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFF59E0B), modifier = Modifier.padding(1.dp))
                    }
                }
            }
            review.comment?.takeIf { it.isNotBlank() }?.let {
                Spacer(Modifier.height(6.dp))
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }
            review.replyComment?.takeIf { it.isNotBlank() }?.let {
                Spacer(Modifier.height(8.dp))
                Text("Réponse : $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
                OutlinedButton(onClick = onDeleteReply, modifier = Modifier.fillMaxWidth()) {
                    Text("Supprimer la réponse")
                }
            } ?: run {
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = reply,
                    onValueChange = onReplyChange,
                    label = { Text("Votre réponse") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                )
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = onAiReply, enabled = !aiLoading, modifier = Modifier.weight(1f)) {
                        Text(if (aiLoading) "…" else "Réponse IA")
                    }
                    Button(onClick = onPublishReply, modifier = Modifier.weight(1f)) {
                        Text("Publier")
                    }
                }
            }
        }
    }
}

@Composable
private fun PostsTab(
    posts: List<GoogleBusinessPostRow>,
    postSummary: String,
    posting: Boolean,
    onSummaryChange: (String) -> Unit,
    onPublish: () -> Unit,
) {
    OutlinedTextField(
        value = postSummary,
        onValueChange = { if (it.length <= 1500) onSummaryChange(it) },
        label = { Text("Nouvelle publication") },
        modifier = Modifier.fillMaxWidth(),
        minLines = 3,
        enabled = !posting,
    )
    Spacer(Modifier.height(8.dp))
    Button(onClick = onPublish, enabled = !posting && postSummary.trim().isNotEmpty(), modifier = Modifier.fillMaxWidth()) {
        Text(if (posting) "Publication…" else "Publier sur Google")
    }
    Spacer(Modifier.height(16.dp))
    posts.forEach { post ->
        Card(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        ) {
            Column(Modifier.padding(12.dp)) {
                Text(post.summary?.ifBlank { post.topicType ?: "Publication" } ?: "Publication", fontWeight = FontWeight.Medium)
                post.state?.let { Text(it, style = MaterialTheme.typography.labelSmall) }
            }
        }
    }
}

@Composable
private fun QnaTab(
    questions: List<Pair<String, String>>,
    answerDrafts: Map<String, String>,
    onAnswerChange: (String, String) -> Unit,
    onSubmit: (String, String) -> Unit,
) {
    if (questions.isEmpty()) {
        Text("Aucune question pour l’instant.", color = MaterialTheme.colorScheme.onSurfaceVariant)
        return
    }
    questions.forEach { (id, text) ->
        Card(
            modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        ) {
            Column(Modifier.padding(12.dp)) {
                Text(text, fontWeight = FontWeight.Medium)
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = answerDrafts[id].orEmpty(),
                    onValueChange = { onAnswerChange(id, it) },
                    label = { Text("Votre réponse") },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                )
                Spacer(Modifier.height(6.dp))
                Button(
                    onClick = { onSubmit(id, answerDrafts[id].orEmpty()) },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Publier la réponse") }
            }
        }
    }
}
